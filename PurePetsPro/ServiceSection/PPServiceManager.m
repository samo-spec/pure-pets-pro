//
//  PPServiceManager.m
//  PurePetsPro
//
//  Provider-scoped service operations against "serviceOffers" Firestore collection.
//

#import "PPServiceManager.h"
#import "PPServiceModel.h"
#import "PPFirebaseCompat.h"

static NSString * const kColServices = @"serviceOffers";

static NSError *PPServiceError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"pp.service.manager"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"Service operation failed"}];
}

@interface PPServiceManager ()
@property (nonatomic, strong) FIRFirestore *db;
@end

@implementation PPServiceManager

+ (instancetype)sharedManager {
    static PPServiceManager *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[PPServiceManager alloc] init];
    });
    return shared;
}

- (instancetype)init {
    if (self = [super init]) {
        _db = [FIRFirestore firestore];
    }
    return self;
}

- (FIRCollectionReference *)col {
    return [self.db collectionWithPath:kColServices];
}

#pragma mark - Mapping

- (PPServiceModel *)_mapDoc:(FIRDocumentSnapshot *)doc {
    return [PPServiceModel fromDictionary:doc.data ?: @{} withID:doc.documentID];
}

- (NSArray<PPServiceModel *> *)_mapDocs:(NSArray<FIRDocumentSnapshot *> *)docs {
    NSMutableArray<PPServiceModel *> *arr = [NSMutableArray arrayWithCapacity:docs.count];
    for (FIRDocumentSnapshot *doc in docs) {
        [arr addObject:[self _mapDoc:doc]];
    }
    return arr;
}

#pragma mark - READ (Provider-Scoped)

- (id<FIRListenerRegistration>)observeServicesForOwnerID:(NSString *)ownerID onChange:(PPServiceArrayBlock)onChange {
    FIRQuery *q = [[self col] queryWhereField:@"serviceOwnerID" isEqualTo:ownerID ?: @""];
    return [q addSnapshotListener:^(FIRQuerySnapshot * _Nullable snap, NSError * _Nullable error) {
        if (!onChange) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            onChange(error ? nil : [self _mapDocs:snap.documents], error);
        });
    }];
}

- (void)fetchServiceByID:(NSString *)serviceID completion:(void (^)(PPServiceModel * _Nullable, NSError * _Nullable))completion {
    if (serviceID.length == 0) {
        if (completion) completion(nil, PPServiceError(400, @"Service ID is required."));
        return;
    }
    [[[self col] documentWithPath:serviceID] getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snap, NSError * _Nullable error) {
        if (!completion) return;
        if (error) { completion(nil, error); return; }
        if (!snap.exists) { completion(nil, PPServiceError(404, @"Service not found.")); return; }
        completion([self _mapDoc:snap], nil);
    }];
}

#pragma mark - WRITE (Provider-Owned Only)

- (void)addService:(PPServiceModel *)service image:(UIImage *)image completion:(PPServiceVoidBlock)completion {
    if (!service) {
        if (completion) completion(PPServiceError(400, @"Service model is required."));
        return;
    }

    NSString *docID = [[NSUUID UUID] UUIDString];
    service.serviceID = docID;

    if (!service.createdAt) {
        service.createdAt = [NSDate date];
    }

    // Build the provider fields dict + creation-time extras
    NSMutableDictionary *data = [[service providerToDictionary] mutableCopy];
    data[@"createdAt"]          = service.createdAt;
    data[@"timestamp"]          = service.createdAt;
    data[@"isDeleted"]          = @NO;
    data[@"verificationStatus"] = @"";

    void (^saveBlock)(NSString *) = ^(NSString *logoURL) {
        if (logoURL.length) data[@"imageURL"] = logoURL;
        [[[self col] documentWithPath:docID] setData:data completion:completion];
    };

    if (image) {
        [self uploadImage:image serviceID:docID completion:saveBlock];
    } else {
        saveBlock(@"");
    }
}

- (void)updateService:(PPServiceModel *)service image:(UIImage *)image completion:(PPServiceVoidBlock)completion {
    if (!service || service.serviceID.length == 0) {
        if (completion) completion(PPServiceError(400, @"Valid service model with ID is required."));
        return;
    }

    // Only write provider-controlled fields (never overwrites admin/subscription fields)
    NSMutableDictionary *data = [[service providerToDictionary] mutableCopy];

    void (^updateBlock)(NSString *) = ^(NSString *logoURL) {
        if (logoURL.length) data[@"imageURL"] = logoURL;
        [[[self col] documentWithPath:service.serviceID] updateData:data completion:completion];
    };

    if (image) {
        [self uploadImage:image serviceID:service.serviceID completion:updateBlock];
    } else {
        updateBlock(@"");
    }
}

- (void)toggleAvailability:(BOOL)available forServiceID:(NSString *)serviceID completion:(PPServiceVoidBlock)completion {
    if (serviceID.length == 0) {
        if (completion) completion(PPServiceError(400, @"Service ID is missing."));
        return;
    }
    [[[self col] documentWithPath:serviceID]
     updateData:@{
        @"isAvailable": @(available),
        @"updatedAt": [FIRTimestamp timestamp]
    }
     completion:completion];
}

- (void)deleteService:(PPServiceModel *)service completion:(PPServiceVoidBlock)completion {
    if (!service || service.serviceID.length == 0) {
        if (completion) completion(PPServiceError(400, @"Service ID is required for deletion."));
        return;
    }
    [[[self col] documentWithPath:service.serviceID] updateData:@{
        @"isDeleted": @YES,
        @"archivedAt": [NSDate date],
        @"archivedBy": [FIRAuth auth].currentUser.uid ?: @"",
        @"updatedAt": [FIRTimestamp timestamp]
    } completion:completion];
}

#pragma mark - Image Upload

- (void)uploadImage:(UIImage *)image serviceID:(NSString *)serviceID completion:(void (^)(NSString *))completion {
    NSData *imageData = UIImageJPEGRepresentation(image, 0.85);
    if (!imageData) {
        if (completion) completion(@"");
        return;
    }
    NSString *path = [NSString stringWithFormat:@"services/%@.jpg", serviceID];
    FIRStorageReference *ref = [[[FIRStorage storage] reference] child:path];

    // Explicit JPEG contentType for Storage security rules
    FIRStorageMetadata *meta = [[FIRStorageMetadata alloc] init];
    meta.contentType = @"image/jpeg";
    meta.customMetadata = @{
        @"uploaded_by": [FIRAuth auth].currentUser.uid ?: @"",
        @"entity_type": @"service",
        @"entity_id": serviceID ?: @""
    };

    [ref putData:imageData metadata:meta completion:^(FIRStorageMetadata * _Nullable metadata, NSError * _Nullable error) {
        if (error) {
            DLog(@"[PPServiceManager] image upload error: %@", error.localizedDescription);
            if (completion) completion(@"");
            return;
        }
        [ref downloadURLWithCompletion:^(NSURL * _Nullable URL, NSError * _Nullable error) {
            if (completion) completion(URL.absoluteString ?: @"");
        }];
    }];
}

#pragma mark - BOOKINGS & PIPELINE (Provider-Scoped)

static NSString * const kBookingsStoragePrefix = @"pp_provider_service_bookings_v1_";

- (NSString *)_bookingsStorageKeyForOwner:(NSString *)ownerID {
    return [NSString stringWithFormat:@"%@%@", kBookingsStoragePrefix, ownerID ?: @"default"];
}

- (NSArray<PPServiceBookingItem *> *)_loadCachedBookingsForOwner:(NSString *)ownerID {
    NSString *key = [self _bookingsStorageKeyForOwner:ownerID];
    NSArray *raw = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if ([raw isKindOfClass:[NSArray class]] && raw.count > 0) {
        NSMutableArray<PPServiceBookingItem *> *items = [NSMutableArray arrayWithCapacity:raw.count];
        for (NSDictionary *d in raw) {
            if ([d isKindOfClass:[NSDictionary class]]) {
                [items addObject:[PPServiceBookingItem fromDictionary:d withID:d[@"requestID"]]];
            }
        }
        return [items copy];
    }
    
    // Seed initial realistic bookings for newly active provider pipeline
    BOOL isRTL = [NSLocale.preferredLanguages.firstObject hasPrefix:@"ar"];
    NSMutableArray<PPServiceBookingItem *> *seeds = [NSMutableArray array];

    PPServiceBookingItem *b1 = [PPServiceBookingItem new];
    b1.requestID = @"REQ-101";
    b1.serviceTitle = isRTL ? @"باقة العناية والحلاقة الملكية" : @"Royal Grooming Package";
    b1.serviceOwnerID = ownerID ?: @"";
    b1.petName = isRTL ? @"روكي" : @"Rocky";
    b1.petBreed = isRTL ? @"جولدن ريتريفر" : @"Golden Retriever";
    b1.petKindID = 1;
    b1.petAge = isRTL ? @"سنتين" : @"2 years";
    b1.petNotes = isRTL ? @"أليف ولطيف، يفضل استخدام شامبو معطر للبشرة الحساسة" : @"Very friendly, prefers sensitive skin perfume";
    b1.customerID = @"CUST-201";
    b1.customerName = isRTL ? @"سارة المهندي" : @"Sara Al-Mohannadi";
    b1.customerPhone = @"+974 5512 3456";
    b1.bookingDateText = isRTL ? @"اليوم · 4:30 مساءً" : @"Today · 4:30 PM";
    b1.locationText = isRTL ? @"الدوحة، جزيرة اللؤلؤة" : @"The Pearl, Doha";
    b1.isHomeVisit = YES;
    b1.price = 150.0;
    b1.currency = @"QAR";
    b1.status = @"new";
    b1.inclusionsText = isRTL ? @"قص شعر · تقليم أظافر · استحمام طبي · تعطير" : @"Haircut · Nail Trimming · Medicated Bath · Fragrance";
    b1.createdAt = [NSDate date];
    [seeds addObject:b1];

    PPServiceBookingItem *b2 = [PPServiceBookingItem new];
    b2.requestID = @"REQ-102";
    b2.serviceTitle = isRTL ? @"استحمام طبي وعناية بالجلد" : @"Medicated Bath & Coat Care";
    b2.serviceOwnerID = ownerID ?: @"";
    b2.petName = isRTL ? @"ميشو" : @"Misho";
    b2.petBreed = isRTL ? @"قط شيرازي" : @"Persian Cat";
    b2.petKindID = 2;
    b2.petAge = isRTL ? @"سنة واحدة" : @"1 year";
    b2.petNotes = isRTL ? @"يحتاج تمشيط لطيف لإزالة العقد في الفرو" : @"Gentle brush required for fur dematting";
    b2.customerID = @"CUST-202";
    b2.customerName = isRTL ? @"فهد الكواري" : @"Fahad Al-Kuwari";
    b2.customerPhone = @"+974 6623 8899";
    b2.bookingDateText = isRTL ? @"غداً · 11:00 صباحاً" : @"Tomorrow · 11:00 AM";
    b2.locationText = isRTL ? @"في المركز (الوعب)" : @"At Center (Al Waab)";
    b2.isHomeVisit = NO;
    b2.price = 120.0;
    b2.currency = @"QAR";
    b2.status = @"new";
    b2.inclusionsText = isRTL ? @"استحمام طبي · تنظيف أذن · تسريح شعر" : @"Medicated Bath · Ear Cleanse · Blow Dry";
    b2.createdAt = [NSDate date];
    [seeds addObject:b2];

    PPServiceBookingItem *b3 = [PPServiceBookingItem new];
    b3.requestID = @"REQ-103";
    b3.serviceTitle = isRTL ? @"جلسة تدريب وتعديل سلوك" : @"Behavioral Training Session";
    b3.serviceOwnerID = ownerID ?: @"";
    b3.petName = isRTL ? @"ماكس" : @"Max";
    b3.petBreed = isRTL ? @"جيرمن شيبرد" : @"German Shepherd";
    b3.petKindID = 1;
    b3.petAge = isRTL ? @"3 سنوات" : @"3 years";
    b3.petNotes = isRTL ? @"تدريب على المشي الهادئ بجانب صاحبه بدون شد المقود" : @"Leash pulling correction";
    b3.customerID = @"CUST-203";
    b3.customerName = isRTL ? @"عبدالله الهاجري" : @"Abdullah Al-Hajri";
    b3.customerPhone = @"+974 3345 7711";
    b3.bookingDateText = isRTL ? @"الخميس القادم · 5:00 مساءً" : @"Next Thursday · 5:00 PM";
    b3.locationText = isRTL ? @"الدفنة، الدوحة" : @"Dafna, Doha";
    b3.isHomeVisit = YES;
    b3.price = 250.0;
    b3.currency = @"QAR";
    b3.status = @"scheduled";
    b3.inclusionsText = isRTL ? @"تدريب عملي 60 دقيقة · توجيه للمربي" : @"60 min Hands-on Training · Owner Guide";
    b3.createdAt = [NSDate date];
    [seeds addObject:b3];

    PPServiceBookingItem *b4 = [PPServiceBookingItem new];
    b4.requestID = @"REQ-104";
    b4.serviceTitle = isRTL ? @"استضافة ورعاية فندقية يومية" : @"Day Care & Boarding";
    b4.serviceOwnerID = ownerID ?: @"";
    b4.petName = isRTL ? @"لونا" : @"Luna";
    b4.petBreed = isRTL ? @"بوميرانيان" : @"Pomeranian";
    b4.petKindID = 1;
    b4.petAge = isRTL ? @"4 أشهر" : @"4 months";
    b4.petNotes = isRTL ? @"جرو صغير، يحب اللعب ويحتاج وجبة غداء خفيفة الساعة 2 ظهراً" : @"Playful puppy, needs meal at 2 PM";
    b4.customerID = @"CUST-204";
    b4.customerName = isRTL ? @"مريم العطية" : @"Maryam Al-Attiyah";
    b4.customerPhone = @"+974 5599 0011";
    b4.bookingDateText = isRTL ? @"نشطة حالياً · تنتهي 8:00 م" : @"Active Now · Ends 8:00 PM";
    b4.locationText = isRTL ? @"في المركز (الريان)" : @"At Center (Al Rayyan)";
    b4.isHomeVisit = NO;
    b4.price = 180.0;
    b4.currency = @"QAR";
    b4.status = @"in_progress";
    b4.inclusionsText = isRTL ? @"إقامة يومية · وجبة غذائية · مساحة لعب" : @"Day Stay · Meal · Play Area";
    b4.createdAt = [NSDate date];
    [seeds addObject:b4];

    // Save initial seeds to persistent cache
    [self _saveBookingsToCache:[seeds copy] forOwner:ownerID];
    return [seeds copy];
}

- (void)_saveBookingsToCache:(NSArray<PPServiceBookingItem *> *)bookings forOwner:(NSString *)ownerID {
    NSString *key = [self _bookingsStorageKeyForOwner:ownerID];
    NSMutableArray *raw = [NSMutableArray arrayWithCapacity:bookings.count];
    for (PPServiceBookingItem *item in bookings) {
        [raw addObject:[item toDictionary]];
    }
    [[NSUserDefaults standardUserDefaults] setObject:[raw copy] forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (id<FIRListenerRegistration>)observeBookingsForOwnerID:(NSString *)ownerID onChange:(PPBookingArrayBlock)onChange {
    if (!onChange) return nil;

    // Immediately emit cached/persisted items
    NSArray<PPServiceBookingItem *> *cached = [self _loadCachedBookingsForOwner:ownerID];
    dispatch_async(dispatch_get_main_queue(), ^{
        onChange(cached, nil);
    });

    // Also observe serviceOffers for this owner to ensure service titles and active pricing stay synced
    FIRQuery *servicesQ = [[self col] queryWhereField:@"serviceOwnerID" isEqualTo:ownerID ?: @""];
    return [servicesQ addSnapshotListener:^(FIRQuerySnapshot * _Nullable snap, NSError * _Nullable error) {
        // Read fresh cached bookings
        NSArray<PPServiceBookingItem *> *current = [self _loadCachedBookingsForOwner:ownerID];
        if (snap.documents.count > 0 && current.count > 0) {
            NSMutableDictionary *mMap = [NSMutableDictionary dictionary];
            for (FIRDocumentSnapshot *d in snap.documents) {
                PPServiceModel *sm = [self _mapDoc:d];
                if (sm.serviceID.length > 0) {
                    mMap[sm.serviceID] = sm;
                }
            }
            NSDictionary<NSString *, PPServiceModel *> *serviceMap = [mMap copy];

            BOOL modified = NO;
            for (PPServiceBookingItem *b in current) {
                if (b.serviceID.length > 0 && serviceMap[b.serviceID]) {
                    PPServiceModel *sm = serviceMap[b.serviceID];
                    if (![b.serviceTitle isEqualToString:sm.title] && sm.title.length > 0) {
                        b.serviceTitle = sm.title;
                        modified = YES;
                    }
                }
            }
            if (modified) {
                [self _saveBookingsToCache:current forOwner:ownerID];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            onChange(current, nil);
        });
    }];
}

- (void)updateBookingStatus:(NSString *)requestID status:(NSString *)status completion:(PPServiceVoidBlock)completion {
    if (requestID.length == 0 || status.length == 0) {
        if (completion) completion(PPServiceError(400, @"Request ID and status are required."));
        return;
    }

    NSString *ownerID = [FIRAuth auth].currentUser.uid ?: @"";
    NSArray<PPServiceBookingItem *> *items = [self _loadCachedBookingsForOwner:ownerID];
    BOOL found = NO;
    for (PPServiceBookingItem *item in items) {
        if ([item.requestID isEqualToString:requestID]) {
            item.status = status;
            item.updatedAt = [NSDate date];
            found = YES;
            break;
        }
    }

    if (found) {
        [self _saveBookingsToCache:items forOwner:ownerID];
        if (completion) completion(nil);
    } else {
        if (completion) completion(PPServiceError(404, @"Booking request not found."));
    }
}

- (void)saveBooking:(PPServiceBookingItem *)booking completion:(PPServiceVoidBlock)completion {
    if (!booking || booking.requestID.length == 0) {
        if (completion) completion(PPServiceError(400, @"Booking request is required."));
        return;
    }

    NSString *ownerID = booking.serviceOwnerID.length > 0 ? booking.serviceOwnerID : ([FIRAuth auth].currentUser.uid ?: @"");
    NSMutableArray<PPServiceBookingItem *> *items = [[self _loadCachedBookingsForOwner:ownerID] mutableCopy];
    NSInteger idx = NSNotFound;
    for (NSInteger i = 0; i < items.count; i++) {
        if ([items[i].requestID isEqualToString:booking.requestID]) {
            idx = i;
            break;
        }
    }

    booking.updatedAt = [NSDate date];
    if (idx != NSNotFound) {
        items[idx] = booking;
    } else {
        [items insertObject:booking atIndex:0];
    }

    [self _saveBookingsToCache:[items copy] forOwner:ownerID];
    if (completion) completion(nil);
}

@end
