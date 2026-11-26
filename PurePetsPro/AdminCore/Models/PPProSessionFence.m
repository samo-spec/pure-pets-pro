#import "PPProSessionFence.h"

@interface PPProSessionFence ()
@property (nonatomic, copy, nullable) NSString *observedUID;
@property (nonatomic, weak, nullable) id observedIdentity;
@property (nonatomic, strong) NSUUID *generation;
@end

@implementation PPProSessionFence
+ (instancetype)shared {
    static PPProSessionFence *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [PPProSessionFence new]; });
    return instance;
}
- (void)observeActiveUID:(NSString *)uid identity:(id)identity {
    @synchronized (self) {
        [self observeUID:uid identity:identity];
    }
}
- (instancetype)init {
    if ((self = [super init])) _generation = [NSUUID UUID];
    return self;
}

// All callers hold the monitor. Object identity distinguishes a fresh login
// even if the Firebase UID is unchanged. Explicit invalidation handles logout.
- (void)observeUID:(NSString *)uid identity:(id)identity {
    if (self.observedIdentity != identity ||
        !(self.observedUID == uid || [self.observedUID isEqualToString:uid])) {
        self.observedUID = uid;
        self.observedIdentity = identity;
        self.generation = [NSUUID UUID];
    }
}
- (NSUUID *)captureForUID:(NSString *)requestedUID activeUID:(NSString *)activeUID identity:(id)identity {
    @synchronized (self) {
        [self observeUID:activeUID identity:identity];
        if (!identity || !requestedUID.length || ![requestedUID isEqualToString:activeUID]) return nil;
        return self.generation;
    }
}
- (BOOL)accepts:(NSUUID *)generation requestedUID:(NSString *)requestedUID activeUID:(NSString *)activeUID identity:(id)identity {
    @synchronized (self) {
        [self observeUID:activeUID identity:identity];
        return identity && requestedUID.length && [requestedUID isEqualToString:activeUID] &&
               generation && [self.generation isEqual:generation];
    }
}
- (void)invalidate {
    @synchronized (self) {
        self.observedUID = nil;
        self.observedIdentity = nil;
        self.generation = [NSUUID UUID];
    }
}
@end
