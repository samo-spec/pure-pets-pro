//
//  ChatBubbleView.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/07/2025.
//  Copied to PurePetsPro for messaging parity

#import <UIKit/UIKit.h>
#import "ChatMessageModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface ChatBubbleView : UIView

@property (nonatomic) ChatBubbleContentType contentType;

@property (nonatomic, readonly) UILabel *messageLabel;
@property (nonatomic, readonly) UILabel *timeLabel;
@property (nonatomic, readonly) UIImageView *statusImageView;
/// If you want to control maximum bubble width from the outside
@property (nonatomic) CGFloat maxBubbleWidth;
-(UIImageView *)getStatusImageView;
/// Whether this bubble is incoming
@property (nonatomic, assign) BOOL isIncoming;
@property (nonatomic, assign) PPChatGroupPosition groupPosition;
@property (nonatomic, readonly) BOOL isDeleted;
- (BOOL)isSingleLineMessage;
- (BOOL)pp_isEmojiOnlyText:(NSString *)text;
- (void)setMessageText:(NSString *)message
                   time:(NSDate *)date
            isIncoming:(BOOL)isIncoming
                status:(ChatMessageStatus)status;
- (void)setReplyPreviewTitle:(nullable NSString *)title
                     subtitle:(nullable NSString *)subtitle
                   isIncoming:(BOOL)isIncoming;
- (void)clearReplyPreview;
- (void)setDeleted:(BOOL)deleted animated:(BOOL)animated;
- (void)updateMessageStatus:(ChatMessageModel *)message animated:(BOOL)animated;
/// Applies a contrast-safe foreground before UIKit snapshots the bubble for a
/// context menu, then restores the normal palette after dismissal.
- (void)setContextMenuPresentationActive:(BOOL)active;
@end

@interface ChatMediaBubbleView : UIView
@property (nonatomic, assign) BOOL isIncoming;
@property (nonatomic, assign) PPChatGroupPosition groupPosition;
@property (nonatomic, assign) CGFloat preferredMaximumCornerRadius;
@end

NS_ASSUME_NONNULL_END