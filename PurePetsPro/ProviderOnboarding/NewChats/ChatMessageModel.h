//
//  ChatMessageModel.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/07/2025.
//  Copied to PurePetsPro for messaging parity

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

// Message status lifecycle (Pending → Sending → Sent → Delivered → Read)

@interface ChatMessageModel : NSObject <NSSecureCoding>

@property (nonatomic, assign) ChatMessageStatus status;

@property (nonatomic, assign) ChatMessageType messageType;
@property (nonatomic, strong) NSArray<NSNumber *> *waveformSamples;
@property (nonatomic, strong) NSString *ID;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) NSString *senderID;
@property (nonatomic, strong) NSString *receiverID;
@property (nonatomic, strong) NSDate *timestamp;

// Nova Product integration
@property (nonatomic, copy, nullable) NSArray<PetAccessory *> *novaProducts;
@property (nonatomic, copy, nullable) NSArray<NSDictionary<NSString *, id> *> *novaOptions;
@property (nonatomic, copy, nullable) NSString *novaRequestID;
@property (nonatomic, copy, nullable) NSString *novaResponseID;

// Delivery / Read timestamps (set by receiver)
@property (nonatomic, strong, nullable) NSDate *deliveredAt;
@property (nonatomic, strong, nullable) NSDate *readAt;

// Convenience
@property (nonatomic, readonly) BOOL isTextMessage;
@property (nonatomic, readonly) BOOL isImageMessage;
@property (nonatomic, readonly) BOOL isAudioMessage;
@property (nonatomic, readonly) BOOL isVideoMessage;
@property (nonatomic, readonly) BOOL isFileMessage;
@property (nonatomic, readonly) BOOL isStickerMessage;
@property (nonatomic, copy)   NSString *blurHash;
// Common
@property (nonatomic, strong, nullable) NSString *fileURL;
@property (nonatomic, strong, nullable) NSString *thumbnailURL;
@property (nonatomic, strong, nullable) UIImage *thumbnailImage;
@property (nonatomic, assign) NSInteger fileSize;          // bytes
@property (nonatomic, strong, nullable) NSString *mimeType;

// Media (Audio / Image / Video)
@property (nonatomic, assign) NSTimeInterval mediaDuration; // seconds (audio/video)
@property (nonatomic, strong, nullable) NSString *stickerStoragePath;

// Image / Video dimensions (for layout & aspect ratio)
@property (nonatomic, assign) CGFloat mediaWidth;   // px
@property (nonatomic, assign) CGFloat mediaHeight;  // px
@property (nonatomic, assign) CGFloat cachedMediaHeight;   // px
@property (nonatomic, assign) CGFloat mediaAspectRatio; // height / width


// Upload / Download
@property (nonatomic, assign) BOOL isUploading;
@property (nonatomic, assign) BOOL isDownloading;
@property (nonatomic, assign) float transferProgress;       // 0.0 - 1.0
 
// Local-only (never from Firestore)
@property (nonatomic) BOOL isLocalPending;
// Message lifecycle
@property (nonatomic, assign) BOOL isDeleted;
@property (nonatomic, assign) BOOL isEdited;

// Reply / Forward (future-proof)
@property (nonatomic, strong, nullable) NSString *replyToMessageID;
@property (nonatomic, assign) BOOL isForwarded;

// Encryption / protection ready
@property (nonatomic, assign) BOOL isEncrypted;
@property (nonatomic, strong, nullable) NSString *encryptionVersion;

- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;
@property (nonatomic, strong) UIImage *localImage;
@property (nonatomic, strong) UIColor *cachedBubbleColor;
@property (nonatomic, strong, nullable) NSURL *localVideoURL;
// Layout helpers
 - (void)updateFromDictionary:(NSDictionary *)dict;
@property (nonatomic, assign) BOOL didAnimateInsert;
@property (nonatomic, assign) BOOL didAnimateNovaWordReveal;
 
@end

NS_ASSUME_NONNULL_END