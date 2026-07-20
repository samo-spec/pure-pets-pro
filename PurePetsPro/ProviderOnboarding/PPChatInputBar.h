//
//  PPChatInputBar.h
//  PurePetsPro
//
//  ChatGPT-style floating input bar with auto-growing UITextView
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol PPChatInputBarDelegate <NSObject>
@optional
- (void)chatInputBar:(UIView *)inputBar didTapSendWithText:(NSString *)text;
- (void)chatInputBarDidTapAttachment:(UIView *)inputBar;
- (void)chatInputBarDidStartRecording:(UIView *)inputBar;
- (void)chatInputBar:(UIView *)inputBar didFinishRecordingAtURL:(NSURL *)fileURL duration:(NSTimeInterval)duration waveformSamples:(NSArray<NSNumber *> *)waveformSamples;
- (void)chatInputBarDidCancelRecording:(UIView *)inputBar;
- (void)chatInputBarRecordingPermissionDenied:(UIView *)inputBar;
- (void)chatInputBar:(UIView *)inputBar didFailRecordingWithError:(NSError *)error;
- (void)chatInputBar:(UIView *)inputBar textDidChange:(NSString *)text;
- (void)chatInputBar:(UIView *)inputBar heightDidChange:(CGFloat)height;
@end

@interface PPChatInputBar : UIView <UITextViewDelegate>

@property (nonatomic, weak) id<PPChatInputBarDelegate> delegate;
@property (nonatomic, strong) NSString *placeholder;
@property (nonatomic, assign) CGFloat minHeight;
@property (nonatomic, assign) CGFloat maxHeight;
@property (nonatomic, strong, readonly) UITextView *textView;
@property (nonatomic, assign) BOOL isRecording;

- (instancetype)initWithFrame:(CGRect)frame;
- (void)clearInput;
- (void)setInputEnabled:(BOOL)enabled;
- (void)setSending:(BOOL)sending;
- (void)setRecording:(BOOL)recording;
- (void)cancelRecording;

@end

NS_ASSUME_NONNULL_END
