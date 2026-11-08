#import <UIKit/UIKit.h>

@class PPProviderMarketItem;

@interface PPProviderMarketItemEditorViewController : UIViewController

- (instancetype)initWithItem:(PPProviderMarketItem *)item;
- (instancetype)initForCreate;

@property (nonatomic, copy) void (^onSave)(void);
@property (nonatomic, assign) NSInteger initialAccessKindType;

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
- (UIView *)pp_cardSurface;
- (UIView *)pp_variantStudioBlock;
- (void)pp_refreshVariantStudioBlock;
- (void)pp_openVariantStudio;
- (void)pp_stageProductForOptionsAndOpenStudio;
- (UIView *)pp_sectionHeader:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)iconName;
- (void)pp_pickImage;
- (void)saveTapped;

@end
