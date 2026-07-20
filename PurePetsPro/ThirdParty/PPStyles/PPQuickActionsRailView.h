//
//  PPQuickActionsRailView.h
//  PurePetsPro
//
//  Premium horizontal quick actions scroll rail for Pro dashboard.
//  Apple-level business control center design.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, PPDashboardQuickActionRailStyle) {
    PPDashboardQuickActionRailStyleOwner,
    PPDashboardQuickActionRailStyleDeliveryMember,
};

NS_ASSUME_NONNULL_BEGIN

@interface PPDashboardQuickActionRailItem : NSObject
@property (nonatomic, copy) NSString *titleKey;
@property (nonatomic, copy) NSString *subtitleKey;
@property (nonatomic, copy) NSString *iconName;
@property (nonatomic, copy, nullable) NSString *badgeText;
@property (nonatomic, copy, nullable) void (^handler)(void);
@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, assign) BOOL showsChevron;
+ (instancetype)itemWithTitleKey:(NSString *)titleKey
                       subtitleKey:(nullable NSString *)subtitleKey
                          iconName:(NSString *)iconName
                        badgeText:(nullable NSString *)badgeText
                           enabled:(BOOL)isEnabled
                      chevron:(BOOL)showsChevron
                         handler:(nullable void (^)(void))handler;
@end

@interface PPQuickActionsRailView : UIView
@property (nonatomic, strong) NSArray<PPDashboardQuickActionRailItem *> *actions;
@property (nonatomic, assign) PPDashboardQuickActionRailStyle style;
@property (nonatomic, strong) UIColor *tintColorForIcons;
@property (nonatomic, copy, nullable) NSString *titleKey;
@property (nonatomic, copy, nullable) NSString *subtitleKey;
@property (nonatomic, copy, nullable) NSString *trailingTitleKey;
@property (nonatomic, copy, nullable) void (^trailingHandler)(void);
- (void)reloadActions;
- (void)animateEntrance;
@end

NS_ASSUME_NONNULL_END
