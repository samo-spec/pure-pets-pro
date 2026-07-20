//
//  PPChatsFunc.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 19/01/2026.
//  Copied to PurePetsPro for messaging parity

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ChatMessageStatusUpdatable <NSObject>
- (void)updateMessageStatus:(ChatMessageModel *)message;
@end


@protocol PPChatBubbleColorProviding <NSObject>
@required
- (UIColor *)pp_bubbleBackgroundColor;
@end


  
@interface PPChatsFunc : NSObject
+ (NSString *)formattedCurrency:(CGFloat)value;
/// Replaces Arabic-Indic digits (٠-٩) with Latin digits (0-9).
+ (NSString *)pp_forceLatinDigits:(NSString *)input;
+ (void)applyGlowIfNeededToBubble:(UIView *)bubble
                              path:(UIBezierPath *)path
                          showGlow:(BOOL)showGlow
                        isIncoming:(BOOL)isIncoming;


+ (void)applyBubbleMask:(UIView *)bubble
             isIncoming:(BOOL)isIncoming
          groupPosition:(PPChatGroupPosition)position
               showGlow:(BOOL)showGlow;


/// Physical alignment derived from ownership and the active interface direction.
+ (BOOL)bubbleUsesTrailingAlignmentForIncoming:(BOOL)isIncoming;

/// Shared premium message-surface palette. Keeps text, audio, image and video
/// bubbles visually consistent in light/dark mode without duplicating colors.
+ (UIColor *)chatCanvasBackgroundColor;
+ (UIColor *)chatNeutralAccentColor;
+ (UIColor *)bubbleSurfaceColorForIncoming:(BOOL)isIncoming;
+ (UIColor *)bubblePrimaryContentColorForIncoming:(BOOL)isIncoming;
+ (UIColor *)bubbleSecondaryContentColorForIncoming:(BOOL)isIncoming;
+ (UIColor *)bubbleStrokeColorForIncoming:(BOOL)isIncoming;
+ (UIColor *)bubbleInteractiveAccentColorForIncoming:(BOOL)isIncoming;
+ (UIColor *)bubblePlaybackControlSurfaceColorForIncoming:(BOOL)isIncoming;
+ (UIColor *)bubbleWaveInactiveColorForIncoming:(BOOL)isIncoming;
+ (UIColor *)bubbleReplySurfaceColorForIncoming:(BOOL)isIncoming;

/// Shared delivery/read-state renderer used by every message cell.
+ (void)applyStatusForMessage:(ChatMessageModel *)message
                  toImageView:(UIImageView *)imageView
                   isIncoming:(BOOL)isIncoming
                     animated:(BOOL)animated;


- (instancetype)init NS_UNAVAILABLE;
+ (UIButton *)buttonWithSystemName:(NSString *)imageName
                      buttonSide:(float)side
                        target:(id)target
                        action:(nullable SEL)action;
  
@end


@interface PPChatGradientView : UIView

- (void)applyTopGradient;
- (void)applyBottomGradient;

@end


@interface PPChatBackgroundManager : NSObject

+ (instancetype)shared;

/// Fetch random background (1–10)
- (void)fetchRandomChatBackground:(void (^)(UIImage * _Nullable image))completion;

/// Fetch background by index (1–10)
- (void)fetchChatBackgroundAtIndex:(NSInteger)index
                      completion:(void (^)(UIImage * _Nullable image))completion;

@end


NS_ASSUME_NONNULL_END