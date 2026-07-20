//
//  ChatMessageModel.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 28/07/2025.
//  Copied to PurePetsPro for messaging parity

#import "ChatMessageModel.h"
#import <FirebaseFirestore/FirebaseFirestore.h>

@implementation ChatMessageModel

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

#pragma mark - Init (Firestore / Dictionary)

- (instancetype)initWithDictionary:(NSDictionary *)dict
{
    self = [super init];
    if (self) {

        // Core
        _ID = dict[@"ID"] ?: dict[@"id"] ?: @"";
        _text = dict[@"text"] ?: @"";
        _senderID = dict[@"senderID"] ?: dict[@"sender_id"] ?: @"";
        _receiverID = dict[@"receiverID"] ?: dict[@"receiver_id"] ?: @"";

        // Timestamp (Firestore-safe)
        id ts = dict[@"timestamp"];
        if ([ts isKindOfClass:[FIRTimestamp class]]) {
            _timestamp = [(FIRTimestamp *)ts dateValue];
        } else if ([ts isKindOfClass:[NSDate class]]) {
            _timestamp = ts;
        } else {
            _timestamp = [NSDate date];
        }

        // DeliveredAt (Firestore-safe)
        id delivered = dict[@"deliveredAt"];
        if ([delivered isKindOfClass:[FIRTimestamp class]]) {
            _deliveredAt = [(FIRTimestamp *)delivered dateValue];
        } else if ([delivered isKindOfClass:[NSDate class]]) {
            _deliveredAt = delivered;
        }

        // ReadAt (Firestore-safe)
        id read = dict[@"readAt"];
        if ([read isKindOfClass:[FIRTimestamp class]]) {
            _readAt = [(FIRTimestamp *)read dateValue];
        } else if ([read isKindOfClass:[NSDate class]]) {
            _readAt = read;
        }

        // Status
        NSNumber *statusNumber = dict[@"status"];
        _status = statusNumber ? (ChatMessageStatus)statusNumber.integerValue
                               : ChatMessageStatusSent;

        // Type
        NSNumber *typeNumber = dict[@"type"];
        _messageType = typeNumber ? (ChatMessageType)typeNumber.integerValue
                                   : ChatMessageTypeText;
        _novaRequestID = dict[@"novaRequestID"] ?: dict[@"nova_request_id"];
        _novaResponseID = dict[@"novaResponseID"] ?: dict[@"nova_response_id"];
        id novaOptions = dict[@"novaOptions"] ?: dict[@"nova_options"];
        if ([novaOptions isKindOfClass:NSArray.class]) {
            _novaOptions = novaOptions;
        }

        // Media
        _fileURL      = dict[@"fileURL"] ?: dict[@"file_url"];
        _blurHash     = dict[@"blurHash"] ?: dict[@"blur_hash"];
        _thumbnailURL = dict[@"thumbnailURL"] ?: dict[@"thumbnail_url"];
        _mimeType     = dict[@"mimeType"] ?: dict[@"mime_type"];
        _stickerStoragePath = dict[@"stickerStoragePath"] ?: dict[@"sticker_storage_path"];
        _fileSize = [dict[@"fileSize"] ?: dict[@"file_size"] integerValue];
        _mediaDuration = [dict[@"mediaDuration"] ?: dict[@"media_duration"] doubleValue];
        
        id waveform = dict[@"waveform"];
        if ([waveform isKindOfClass:[NSArray class]]) {
            NSMutableArray *clean = [NSMutableArray array];
            for (id v in waveform) {
                if ([v isKindOfClass:[NSNumber class]]) {
                    [clean addObject:v];
                }
            }
            _waveformSamples = clean;
        }
        
        _mediaWidth  = [dict[@"mediaWidth"]  ?: dict[@"media_width"]  doubleValue];
        _mediaHeight = [dict[@"mediaHeight"] ?: dict[@"media_height"] doubleValue];
        _cachedMediaHeight = [dict[@"cachedMediaHeight"] ?: dict[@"cached_media_height"] doubleValue];
        _mediaAspectRatio  = [dict[@"mediaAspectRatio"]  ?: dict[@"media_aspect_ratio"]  doubleValue];
        if (_mediaAspectRatio <= 0 && _mediaWidth > 0 && _mediaHeight > 0) {
            _mediaAspectRatio = _mediaHeight / _mediaWidth;
        }

        // Transfer
        _isUploading =
            dict[@"isUploading"] ? [dict[@"isUploading"] boolValue]
                                 : [dict[@"is_uploading"] boolValue];

        _isDownloading =
            dict[@"isDownloading"] ? [dict[@"isDownloading"] boolValue]
                                    : [dict[@"is_downloading"] boolValue];

        _transferProgress =
            dict[@"transferProgress"] ? [dict[@"transferProgress"] floatValue]
                                      : [dict[@"transfer_progress"] floatValue];

        // Lifecycle
        _isDeleted = [dict[@"isDeleted"] ?: dict[@"is_deleted"] boolValue];
        _isEdited  = [dict[@"isEdited"]  ?: dict[@"is_edited"]  boolValue];

        // Reply / Forward
        _replyToMessageID = dict[@"replyTo"] ?: dict[@"reply_to"];
        _isForwarded = [dict[@"isForwarded"] ?: dict[@"is_forwarded"] boolValue];

        // Encryption (future-proof)
        _isEncrypted = [dict[@"isEncrypted"] ?: dict[@"is_encrypted"] boolValue];
        _encryptionVersion = dict[@"encryptionVersion"] ?: dict[@"encryption_version"];
    }
    return self;
}

#pragma mark - Serialization

- (NSDictionary *)toDictionary
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    dict[@"ID"] = self.ID ?: @"";
    dict[@"text"] = self.text ?: @"";
    dict[@"senderID"] = self.senderID ?: @"";
    dict[@"receiverID"] = self.receiverID ?: @"";
    dict[@"timestamp"] = self.timestamp ?: [NSDate date];
    if (self.deliveredAt) dict[@"deliveredAt"] = self.deliveredAt;
    if (self.readAt)      dict[@"readAt"] = self.readAt;
    dict[@"status"] = @(self.status);
    dict[@"type"] = @(self.messageType);
    if (self.novaRequestID.length > 0) dict[@"novaRequestID"] = self.novaRequestID;
    if (self.novaResponseID.length > 0) dict[@"novaResponseID"] = self.novaResponseID;
    if (self.novaOptions.count > 0) dict[@"novaOptions"] = self.novaOptions;

    if (self.fileURL)        dict[@"fileURL"] = self.fileURL;
    if (self.thumbnailURL)   dict[@"thumbnailURL"] = self.thumbnailURL;
    if (self.blurHash)       dict[@"blurHash"] = self.blurHash;
    if (self.stickerStoragePath.length > 0) dict[@"stickerStoragePath"] = self.stickerStoragePath;
    
    if (self.mimeType)       dict[@"mimeType"] = self.mimeType;
    if (self.fileSize > 0)   dict[@"fileSize"] = @(self.fileSize);
    if (self.mediaDuration > 0)
        dict[@"mediaDuration"] = @(self.mediaDuration);
    if (self.mediaWidth > 0)
        dict[@"mediaWidth"] = @(self.mediaWidth);

    if (self.mediaHeight > 0)
        dict[@"mediaHeight"] = @(self.mediaHeight);
    
    if (self.cachedMediaHeight > 0)
        dict[@"cachedMediaHeight"] = @(self.cachedMediaHeight);
    
    if (self.mediaAspectRatio > 0)
        dict[@"mediaAspectRatio"] = @(self.mediaAspectRatio);

    if (self.messageType == ChatMessageTypeVideo ||
        self.messageType == ChatMessageTypeImage ||
        self.messageType == ChatMessageTypeSticker) {
        dict[@"hasMedia"] = @YES;
    }
    
    if (self.waveformSamples.count > 0) {
        dict[@"waveform"] = self.waveformSamples;
    }

    dict[@"isUploading"] = @(self.isUploading);
    dict[@"isDownloading"] = @(self.isDownloading);
    dict[@"transferProgress"] = @(self.transferProgress);

    dict[@"isDeleted"] = @(self.isDeleted);
    dict[@"isEdited"]  = @(self.isEdited);

    if (self.replyToMessageID)
        dict[@"replyTo"] = self.replyToMessageID;

    dict[@"isForwarded"] = @(self.isForwarded);
    dict[@"isEncrypted"] = @(self.isEncrypted);

    if (self.encryptionVersion)
        dict[@"encryptionVersion"] = self.encryptionVersion;

    return dict;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.ID forKey:@"ID"];
    [coder encodeObject:self.text forKey:@"text"];
    [coder encodeObject:self.senderID forKey:@"senderID"];
    [coder encodeObject:self.receiverID forKey:@"receiverID"];
    [coder encodeObject:self.timestamp forKey:@"timestamp"];
    [coder encodeObject:self.deliveredAt forKey:@"deliveredAt"];
    [coder encodeObject:self.readAt forKey:@"readAt"];
    [coder encodeInteger:self.status forKey:@"status"];
    [coder encodeInteger:self.messageType forKey:@"type"];
    [coder encodeObject:self.novaProducts forKey:@"novaProducts"];
    [coder encodeObject:self.novaOptions forKey:@"novaOptions"];
    [coder encodeObject:self.novaRequestID forKey:@"novaRequestID"];
    [coder encodeObject:self.novaResponseID forKey:@"novaResponseID"];

    [coder encodeObject:self.blurHash forKey:@"blurHash"];
    [coder encodeObject:self.fileURL forKey:@"fileURL"];
    [coder encodeObject:self.thumbnailURL forKey:@"thumbnailURL"];
    [coder encodeObject:self.mimeType forKey:@"mimeType"];
    [coder encodeObject:self.stickerStoragePath forKey:@"stickerStoragePath"];
    [coder encodeInteger:self.fileSize forKey:@"fileSize"];
    [coder encodeDouble:self.mediaDuration forKey:@"mediaDuration"];
    [coder encodeDouble:self.mediaWidth forKey:@"mediaWidth"];
    [coder encodeDouble:self.mediaHeight forKey:@"mediaHeight"];
    [coder encodeDouble:self.cachedMediaHeight forKey:@"cachedMediaHeight"];
    [coder encodeDouble:self.mediaAspectRatio forKey:@"mediaAspectRatio"];
    
    [coder encodeObject:self.waveformSamples forKey:@"waveformSamples"];

    [coder encodeBool:self.isUploading forKey:@"isUploading"];
    [coder encodeBool:self.isDownloading forKey:@"isDownloading"];
    [coder encodeFloat:self.transferProgress forKey:@"transferProgress"];

    [coder encodeBool:self.isDeleted forKey:@"isDeleted"];
    [coder encodeBool:self.isEdited forKey:@"isEdited"];

    [coder encodeObject:self.replyToMessageID forKey:@"replyTo"];
    [coder encodeBool:self.isForwarded forKey:@"isForwarded"];

    [coder encodeBool:self.isEncrypted forKey:@"isEncrypted"];
    [coder encodeObject:self.encryptionVersion forKey:@"encryptionVersion"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _ID = [coder decodeObjectOfClass:NSString.class forKey:@"ID"];
        _text = [coder decodeObjectOfClass:NSString.class forKey:@"text"];
        _senderID = [coder decodeObjectOfClass:NSString.class forKey:@"senderID"];
        _receiverID = [coder decodeObjectOfClass:NSString.class forKey:@"receiverID"];
        _timestamp = [coder decodeObjectOfClass:NSDate.class forKey:@"timestamp"];
        _deliveredAt = [coder decodeObjectOfClass:NSDate.class forKey:@"deliveredAt"];
        _readAt = [coder decodeObjectOfClass:NSDate.class forKey:@"readAt"];
        _status = [coder decodeIntegerForKey:@"status"];
        _messageType = [coder decodeIntegerForKey:@"type"];
        _novaProducts = [coder decodeObjectOfClass:[NSArray class] forKey:@"novaProducts"];
        NSSet *novaOptionClasses = [NSSet setWithObjects:NSArray.class, NSDictionary.class, NSString.class, NSNumber.class, NSNull.class, nil];
        _novaOptions = [coder decodeObjectOfClasses:novaOptionClasses forKey:@"novaOptions"];
        _novaRequestID = [coder decodeObjectOfClass:NSString.class forKey:@"novaRequestID"];
        _novaResponseID = [coder decodeObjectOfClass:NSString.class forKey:@"novaResponseID"];

        _blurHash = [coder decodeObjectOfClass:NSString.class forKey:@"blurHash"];
        _fileURL = [coder decodeObjectOfClass:NSString.class forKey:@"fileURL"];
        _thumbnailURL = [coder decodeObjectOfClass:NSString.class forKey:@"thumbnailURL"];
        _mimeType = [coder decodeObjectOfClass:NSString.class forKey:@"mimeType"];
        _stickerStoragePath = [coder decodeObjectOfClass:NSString.class forKey:@"stickerStoragePath"];
        _fileSize = [coder decodeIntegerForKey:@"fileSize"];
        _mediaDuration = [coder decodeDoubleForKey:@"mediaDuration"];
        _mediaWidth = [coder decodeDoubleForKey:@"mediaWidth"];
        _mediaHeight = [coder decodeDoubleForKey:@"mediaHeight"];
        _cachedMediaHeight = [coder decodeDoubleForKey:@"cachedMediaHeight"];
        _mediaAspectRatio = [coder decodeDoubleForKey:@"mediaAspectRatio"];
        
        _waveformSamples =
            [coder decodeObjectOfClass:[NSArray class]
                                forKey:@"waveformSamples"];

        _isUploading = [coder decodeBoolForKey:@"isUploading"];
        _isDownloading = [coder decodeBoolForKey:@"isDownloading"];
        _transferProgress = [coder decodeFloatForKey:@"transferProgress"];

        _isDeleted = [coder decodeBoolForKey:@"isDeleted"];
        _isEdited = [coder decodeBoolForKey:@"isEdited"];

        _replyToMessageID = [coder decodeObjectOfClass:NSString.class forKey:@"replyTo"];
        _isForwarded = [coder decodeBoolForKey:@"isForwarded"];

        _isEncrypted = [coder decodeBoolForKey:@"isEncrypted"];
        _encryptionVersion = [coder decodeObjectOfClass:NSString.class forKey:@"encryptionVersion"];
    }
    return self;
}

#pragma mark - Convenience

- (BOOL)isTextMessage
{
    return self.messageType == ChatMessageTypeText;
}

- (BOOL)isImageMessage
{
    return self.messageType == ChatMessageTypeImage;
}

- (BOOL)isAudioMessage
{
    return self.messageType == ChatMessageTypeAudio;
}

- (BOOL)isVideoMessage
{
    return self.messageType == ChatMessageTypeVideo;
}

- (BOOL)isFileMessage
{
    return self.messageType == ChatMessageTypeFile;
}

- (BOOL)isStickerMessage
{
    return self.messageType == ChatMessageTypeSticker;
}

#pragma mark - Update (Firestore merge)

- (void)updateFromDictionary:(NSDictionary *)dict
{
    if (!dict || ![dict isKindOfClass:NSDictionary.class]) return;

    NSArray *incomingWaveform = dict[@"waveform"];
    BOOL hasIncomingWaveform =
        [incomingWaveform isKindOfClass:[NSArray class]] &&
        incomingWaveform.count > 0;
    
    // 🔒 Preserve UI-only properties
    UIImage *localImage = self.localImage;
    CGFloat cachedHeight = self.cachedMediaHeight;
    BOOL wasUploading = self.isUploading;
    CGFloat progress = self.transferProgress;
    BOOL keepLocalTransferState = self.isLocalPending;
  
    // Text
    NSString *text = dict[@"text"];
    if (text) self.text = text;

    // Status
    NSNumber *statusNumber = dict[@"status"];
    if (statusNumber) {
        self.status = (ChatMessageStatus)statusNumber.integerValue;
    }

    // Delivered / Read timestamps
    id delivered = dict[@"deliveredAt"];
    if ([delivered isKindOfClass:FIRTimestamp.class]) {
        self.deliveredAt = [(FIRTimestamp *)delivered dateValue];
    } else if ([delivered isKindOfClass:NSDate.class]) {
        self.deliveredAt = delivered;
    }

    id read = dict[@"readAt"];
    if ([read isKindOfClass:FIRTimestamp.class]) {
        self.readAt = [(FIRTimestamp *)read dateValue];
    } else if ([read isKindOfClass:NSDate.class]) {
        self.readAt = read;
    }

    // Media URLs (final values)
    NSString *fileURL = dict[@"fileURL"] ?: dict[@"file_url"];
    if (fileURL.length > 0) {
        self.fileURL = fileURL;
    }

    NSString *thumbURL = dict[@"thumbnailURL"] ?: dict[@"thumbnail_url"];
    if (thumbURL.length > 0) {
        self.thumbnailURL = thumbURL;
    }

    NSString *stickerPath = dict[@"stickerStoragePath"] ?: dict[@"sticker_storage_path"];
    if (stickerPath.length > 0) {
        self.stickerStoragePath = stickerPath;
    }

    NSString *blurHash = dict[@"blurHash"] ?: dict[@"blur_hash"];
    if (blurHash.length > 0) {
        self.blurHash = blurHash;
    }
    
    if (hasIncomingWaveform && self.waveformSamples.count == 0) {
        NSMutableArray *clean = [NSMutableArray array];
        for (id v in incomingWaveform) {
            if ([v isKindOfClass:[NSNumber class]]) {
                [clean addObject:v];
            }
        }
        self.waveformSamples = clean;
    }

    // Media metadata (DO NOT overwrite if already set)
    NSNumber *mw = dict[@"mediaWidth"] ?: dict[@"media_width"];
    NSNumber *mh = dict[@"mediaHeight"] ?: dict[@"media_height"];

    if (mw && self.mediaWidth <= 0) {
        self.mediaWidth = mw.doubleValue;
    }

    if (mh && self.mediaHeight <= 0) {
        self.mediaHeight = mh.doubleValue;
    }

    NSNumber *asp = dict[@"mediaAspectRatio"] ?: dict[@"media_aspect_ratio"];
    if (asp.doubleValue > 0) {
        self.mediaAspectRatio = asp.doubleValue;
    }
    if (self.mediaAspectRatio <= 0 && self.mediaWidth > 0 && self.mediaHeight > 0) {
        self.mediaAspectRatio = self.mediaHeight / self.mediaWidth;
    }

    // Cached height: keep local calculation if already present
    NSNumber *cachedH = dict[@"cachedMediaHeight"];
    if (cachedH && self.cachedMediaHeight <= 0) {
        self.cachedMediaHeight = cachedH.doubleValue;
    }

    // Transfer state
    if (dict[@"isUploading"]) {
        self.isUploading = [dict[@"isUploading"] boolValue];
    }

    if (dict[@"isDownloading"]) {
        self.isDownloading = [dict[@"isDownloading"] boolValue];
    }

    if (dict[@"transferProgress"]) {
        self.transferProgress = [dict[@"transferProgress"] floatValue];
    }

    // Flags
    if (dict[@"isDeleted"]) {
        self.isDeleted = [dict[@"isDeleted"] boolValue];
        if (self.isDeleted) {
            // A tombstone must not retain redacted content in the in-memory model.
            self.text = @"";
            self.fileURL = nil;
            self.thumbnailURL = nil;
            self.thumbnailImage = nil;
            self.localImage = nil;
            self.localVideoURL = nil;
            self.blurHash = nil;
            self.stickerStoragePath = nil;
            self.waveformSamples = @[];
            self.mimeType = nil;
            self.fileSize = 0;
            self.mediaDuration = 0.0;
            self.isUploading = NO;
            self.isDownloading = NO;
            self.transferProgress = 0.0;
            self.replyToMessageID = nil;
        }
    }

    if (dict[@"isEdited"]) {
        self.isEdited = [dict[@"isEdited"] boolValue];
    }

    // Forward / reply
    NSString *replyID = dict[@"replyTo"] ?: dict[@"reply_to"];
    if (replyID.length > 0) {
        self.replyToMessageID = replyID;
    }

    if (dict[@"isForwarded"]) {
        self.isForwarded = [dict[@"isForwarded"] boolValue];
    }

    // Encryption (future-proof)
    if (dict[@"isEncrypted"]) {
        self.isEncrypted = [dict[@"isEncrypted"] boolValue];
    }

    NSString *encVer = dict[@"encryptionVersion"] ?: dict[@"encryption_version"];
    if (encVer) {
        self.encryptionVersion = encVer;
    }
    
    // Preserve optimistic upload state only while the message is still live.
    if (!self.isDeleted) {
        self.localImage = localImage;
    }
    if (keepLocalTransferState && !self.isDeleted) {
        self.cachedMediaHeight = cachedHeight;
    }
    if (keepLocalTransferState && !self.isDeleted) {
        self.isUploading = wasUploading;
        self.transferProgress = progress;
    }
  
}

@end