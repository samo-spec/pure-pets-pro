//
//  NotificationManager 2.m
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 24/08/2025.
//


// NotificationManager+Targets.m
#import "NotificationManager+Targets.h"
#import "ChatThreadModel.h"
#import "NotificationModel.h"
#import "PPDeliveryOrderDetailViewController.h"
#import "PPDeliveryOrderModel.h"
#import "PPFulfillmentDetailViewController.h"
#import "PPFulfillmentModel.h"
#import "PPHUD.h"
#import "PPProInAppNotificationPresenter.h"
#import "PPToast.h"
#import "PPUserMessagesViewController.h"
#import "PPFirebaseCompat.h"

static NSString * const kUsersCollection = @"UsersCol"; // ✅ your collection name

static NSString *PPProNotificationTargetsTrimmedString(id value)
{
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if ([value isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)value stringValue];
    }
    return @"";
}

static NSDictionary *PPProNotificationTargetsSafeDictionary(id value)
{
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

static NSString *PPProNotificationTargetsFirstStringForKeys(NSDictionary *source, NSArray<NSString *> *keys)
{
    NSDictionary *safeSource = PPProNotificationTargetsSafeDictionary(source);
    for (NSString *key in keys) {
        NSString *value = PPProNotificationTargetsTrimmedString(safeSource[key]);
        if (value.length > 0) return value;
    }
    return @"";
}

static NSString *PPProNotificationTargetsNestedStringForKeys(NSDictionary *source,
                                                             NSArray<NSString *> *containerKeys,
                                                             NSArray<NSString *> *valueKeys)
{
    NSDictionary *safeSource = PPProNotificationTargetsSafeDictionary(source);
    for (NSString *containerKey in containerKeys) {
        NSDictionary *nested = PPProNotificationTargetsSafeDictionary(safeSource[containerKey]);
        NSString *value = PPProNotificationTargetsFirstStringForKeys(nested, valueKeys);
        if (value.length > 0) return value;
    }
    return @"";
}

static NSString *PPProNotificationTargetsNormalizedString(id value)
{
    NSString *clean = [[PPProNotificationTargetsTrimmedString(value) lowercaseString] copy];
    clean = [clean stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    clean = [clean stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    return clean;
}

static BOOL PPProNotificationTargetsIsCompanyDeliveryPayload(NSDictionary *payload)
{
    NSDictionary *safePayload = PPProNotificationTargetsSafeDictionary(payload);
    NSString *type = PPProNotificationTargetsNormalizedString(PPProNotificationTargetsFirstStringForKeys(safePayload, @[@"notificationType", @"type", @"eventKey"]));
    NSString *route = PPProNotificationTargetsNormalizedString(safePayload[@"route"]);
    return [type hasPrefix:@"company_delivery"] || [route isEqualToString:@"fleet_partner"];
}

static void PPProNotificationTargetsComplete(BOOL handled, void (^completion)(BOOL handled))
{
    if (!completion) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(handled);
    });
}

@implementation NotificationManager (Targets)

#pragma mark - Public

- (void)sendToAudience:(PPAudience)audience
                 model:(NotificationModel *)model
            completion:(void(^)(NSError * _Nullable error))completion
{
    if (audience == PPAudienceAllUsers) {
        // Reuse your existing broadcast
        [self sendBroadcast:model completion:completion];
        return;
    }

    // PPAudienceAppUsers -> fetch all app users (adjust filters if you need)
    FIRFirestore *db = [FIRFirestore firestore];
    [[[db collectionWithPath:kUsersCollection] queryLimitedTo:1000] // adjust paging if huge
     getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (error) { if (completion) completion(error); return; }

        NSMutableArray<NSString *> *userIDs = [NSMutableArray array];
        for (FIRDocumentSnapshot *doc in snapshot.documents) {
            // If you need to exclude admins/moderators, add checks here using doc.data[@"role"]
            [userIDs addObject:doc.documentID];
        }
        [self pp_sendToUserIDs:userIDs model:model completion:completion];
    }];
}

- (void)sendToRoles:(NSArray<NSNumber *> *)roles
              model:(NotificationModel *)model
         completion:(void(^)(NSError * _Nullable error))completion
{
    if (roles.count == 0) { if (completion) completion(nil); return; }

    FIRFirestore *db = [FIRFirestore firestore];

    // Firestore "in" supports up to 10 values; chunk if needed
    NSArray<NSArray<NSNumber *> *> *chunks = [self pp_chunkArray:roles size:10];
    dispatch_group_t group = dispatch_group_create();
    __block NSMutableOrderedSet<NSString *> *allIDs = [NSMutableOrderedSet orderedSet];
    __block NSError *lastError = nil;

    for (NSArray<NSNumber *> *chunk in chunks) {
        dispatch_group_enter(group);
        [[[db collectionWithPath:kUsersCollection]
           queryWhereField:@"role" in:chunk]
         getDocumentsWithCompletion:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
            if (error) { lastError = error; dispatch_group_leave(group); return; }
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                [allIDs addObject:doc.documentID];
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (lastError) { if (completion) completion(lastError); return; }
        [self pp_sendToUserIDs:allIDs.array model:model completion:completion];
    });
}

#pragma mark - Helpers

- (NSArray<NSArray *> *)pp_chunkArray:(NSArray *)array size:(NSUInteger)size {
    if (size == 0 || array.count == 0) return @[array ?: @[]];
    NSMutableArray *chunks = [NSMutableArray array];
    for (NSUInteger i = 0; i < array.count; i += size) {
        NSRange r = NSMakeRange(i, MIN(size, array.count - i));
        [chunks addObject:[array subarrayWithRange:r]];
    }
    return chunks;
}

- (void)pp_sendToUserIDs:(NSArray<NSString *> *)userIDs
                   model:(NotificationModel *)model
              completion:(void(^)(NSError * _Nullable error))completion
{
    if (userIDs.count == 0) { if (completion) completion(nil); return; }

    dispatch_group_t g = dispatch_group_create();
    __block NSError *lastErr = nil;

    for (NSString *uid in userIDs) {
        if (uid.length == 0) continue;
        dispatch_group_enter(g);
        // Reuse your existing per-user API
        [self sendToUser:uid model:model completion:^(NSError * _Nullable error) {
            if (error) lastErr = error;
            dispatch_group_leave(g);
        }];
    }

    dispatch_group_notify(g, dispatch_get_main_queue(), ^{
        if (completion) completion(lastErr);
    });
}

+ (NSDictionary *)routingPayloadForNotificationModel:(NotificationModel *)model
{
    if (![model isKindOfClass:NotificationModel.class]) {
        return nil;
    }

    NSDictionary *meta = PPProNotificationTargetsSafeDictionary(model.meta);
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    for (NSString *containerKey in @[@"order", @"orderData", @"payload"]) {
        NSDictionary *nested = PPProNotificationTargetsSafeDictionary(meta[containerKey]);
        if (nested.count > 0) {
            [payload addEntriesFromDictionary:nested];
        }
    }
    [payload addEntriesFromDictionary:meta];

    NSString *notificationID = PPProNotificationTargetsFirstStringForKeys(payload, @[@"notificationId", @"id"]);
    if (notificationID.length == 0) notificationID = PPProNotificationTargetsTrimmedString(model.nid);
    if (notificationID.length > 0) payload[@"notificationId"] = notificationID;

    NSString *orderID = PPProNotificationTargetsFirstStringForKeys(payload, @[@"orderId", @"orderID", @"parentOrderId", @"parentOrderID"]);
    if (orderID.length > 0) payload[@"orderId"] = orderID;

    NSString *threadID = PPProNotificationTargetsFirstStringForKeys(payload, @[@"conversationId", @"threadId", @"threadID"]);
    if (threadID.length > 0) payload[@"threadId"] = threadID;

    NSString *fulfillmentID = PPProNotificationTargetsFirstStringForKeys(payload, @[@"fulfillmentId", @"fulfillmentID"]);
    if (fulfillmentID.length > 0) payload[@"fulfillmentId"] = fulfillmentID;

    NSString *type = PPProNotificationTargetsFirstStringForKeys(payload, @[@"notificationType", @"type", @"eventKey", @"threadType", @"conversationType", @"route"]);
    if (type.length > 0) {
        payload[@"type"] = type;
        if (PPProNotificationTargetsTrimmedString(payload[@"notificationType"]).length == 0) {
            payload[@"notificationType"] = type;
        }
    }

    NSString *title = [model pp_localizedTitleForCurrentLanguage];
    if (title.length == 0) title = PPProNotificationTargetsTrimmedString(model.title);
    NSString *body = [model pp_localizedBodyForCurrentLanguage];
    if (body.length == 0) body = PPProNotificationTargetsTrimmedString(model.body);
    if (title.length > 0) payload[@"title"] = title;
    if (body.length > 0) payload[@"body"] = body;

    return payload.copy;
}

+ (PPProNotificationTargetKind)targetKindForPayload:(NSDictionary *)payload
{
    NSDictionary *safePayload = PPProNotificationTargetsSafeDictionary(payload);
    if (safePayload.count == 0) {
        return PPProNotificationTargetKindUnknown;
    }

    if (PPProNotificationTargetsIsCompanyDeliveryPayload(safePayload) &&
        PPProNotificationTargetsFirstStringForKeys(safePayload, @[@"requestId"]).length > 0) {
        return PPProNotificationTargetKindCompanyDelivery;
    }

    NSString *threadID = PPProNotificationTargetsFirstStringForKeys(safePayload, @[@"conversationId", @"threadId", @"threadID"]);
    NSString *conversationType = PPProNotificationTargetsNormalizedString(PPProNotificationTargetsFirstStringForKeys(safePayload, @[@"conversationType", @"threadType"]));
    NSString *type = PPProNotificationTargetsNormalizedString(PPProNotificationTargetsFirstStringForKeys(safePayload, @[@"notificationType", @"type", @"eventKey", @"route"]));
    if (threadID.length > 0 ||
        [conversationType containsString:@"chat"] ||
        [conversationType containsString:@"support"] ||
        [type containsString:@"chat"] ||
        [type containsString:@"support"]) {
        return PPProNotificationTargetKindChat;
    }

    NSString *fulfillmentID = PPProNotificationTargetsFirstStringForKeys(safePayload, @[@"fulfillmentId", @"fulfillmentID"]);
    NSString *status = PPProNotificationTargetsNormalizedString(PPProNotificationTargetsFirstStringForKeys(safePayload, @[@"status"]));
    if (fulfillmentID.length > 0 ||
        [type isEqualToString:@"provider_new_fulfillment"] ||
        [type isEqualToString:@"fulfillment_order"] ||
        [status isEqualToString:@"new_request"]) {
        return PPProNotificationTargetKindFulfillment;
    }

    NSString *orderID = PPProNotificationTargetsFirstStringForKeys(safePayload, @[@"orderId", @"orderID", @"parentOrderId", @"parentOrderID"]);
    if (orderID.length > 0 ||
        [type hasPrefix:@"delivery"] ||
        [type hasPrefix:@"drivers_delivery_"] ||
        [type hasPrefix:@"customer_delivery_"] ||
        [type isEqualToString:@"request"] ||
        [type hasPrefix:@"order"]) {
        return PPProNotificationTargetKindDeliveryOrder;
    }

    return PPProNotificationTargetKindUnknown;
}

+ (BOOL)payloadHasDirectTarget:(NSDictionary *)payload
{
    return [self targetKindForPayload:payload] != PPProNotificationTargetKindUnknown;
}

+ (NSString *)callToActionTitleForPayload:(NSDictionary *)payload
{
    switch ([self targetKindForPayload:payload]) {
        case PPProNotificationTargetKindCompanyDelivery:
            return kLang(@"Notification_CTA_OpenDeliveryRequest");
        case PPProNotificationTargetKindFulfillment:
            return kLang(@"Notification_CTA_OpenFulfillment");
        case PPProNotificationTargetKindDeliveryOrder:
            return kLang(@"Notification_CTA_OpenDelivery");
        case PPProNotificationTargetKindChat:
            return kLang(@"Notification_CTA_OpenChat");
        case PPProNotificationTargetKindUnknown:
        default:
            return @"";
    }
}

+ (void)routePayload:(NSDictionary *)payload
fromNavigationController:(UINavigationController *)navigationController
           presenter:(UIViewController *)presenter
          completion:(void (^)(BOOL handled))completion
{
    NSDictionary *safePayload = PPProNotificationTargetsSafeDictionary(payload);
    if (!navigationController || safePayload.count == 0) {
        NSLog(@"[NotificationRoute] Missing navigation controller or payload.");
        PPProNotificationTargetsComplete(NO, completion);
        return;
    }

    PPProNotificationTargetKind targetKind = [self targetKindForPayload:safePayload];
    switch (targetKind) {
        case PPProNotificationTargetKindCompanyDelivery: {
            NSString *requestID = PPProNotificationTargetsFirstStringForKeys(safePayload, @[@"requestId"]);
            if (requestID.length == 0) {
                NSLog(@"[NotificationRoute] Company delivery payload missing requestId.");
                PPProNotificationTargetsComplete(NO, completion);
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:PPProCompanyDeliveryNotificationTappedNotification
                                                                    object:requestID
                                                                  userInfo:safePayload];
                PPProNotificationTargetsComplete(YES, completion);
            });
            return;
        }

        case PPProNotificationTargetKindFulfillment: {
            NSString *fulfillmentID = PPProNotificationTargetsFirstStringForKeys(safePayload, @[@"fulfillmentId", @"fulfillmentID"]);
            if (fulfillmentID.length == 0) {
                NSLog(@"[NotificationRoute] Fulfillment payload missing fulfillmentId.");
                PPProNotificationTargetsComplete(NO, completion);
                return;
            }
            FIRDocumentReference *reference = [[[FIRFirestore firestore] collectionWithPath:@"FulfillmentOrders"] documentWithPath:fulfillmentID];
            [reference getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error || !snapshot.exists || !snapshot.data) {
                        NSLog(@"[NotificationRoute] Fulfillment fetch failed for %@: %@", fulfillmentID, error.localizedDescription ?: @"missing document");
                        [PPHUD showError:kLang(@"Notification_RequestSummaryUnavailable") ?: @"Request details unavailable"];
                        PPProNotificationTargetsComplete(NO, completion);
                        return;
                    }

                    PPFulfillmentModel *model = [PPFulfillmentModel modelFromDictionary:snapshot.data fulfillmentID:snapshot.documentID];
                    if (!model) {
                        PPProNotificationTargetsComplete(NO, completion);
                        return;
                    }
                    PPFulfillmentDetailViewController *controller = [[PPFulfillmentDetailViewController alloc] initWithModel:model];
                    controller.hidesBottomBarWhenPushed = YES;
                    [navigationController pushViewController:controller animated:YES];
                    PPProNotificationTargetsComplete(YES, completion);
                });
            }];
            return;
        }

        case PPProNotificationTargetKindDeliveryOrder: {
            NSString *orderID = PPProNotificationTargetsFirstStringForKeys(safePayload, @[@"orderId", @"orderID", @"parentOrderId", @"parentOrderID"]);
            if (orderID.length == 0) {
                NSLog(@"[NotificationRoute] Delivery payload missing orderId.");
                PPProNotificationTargetsComplete(NO, completion);
                return;
            }
            FIRDocumentReference *reference = [[[FIRFirestore firestore] collectionWithPath:@"Orders"] documentWithPath:orderID];
            [reference getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error || !snapshot.exists || !snapshot.data) {
                        NSLog(@"[NotificationRoute] Order fetch failed for %@: %@", orderID, error.localizedDescription ?: @"missing document");
                        [PPHUD showError:kLang(@"order_support_unavailable_no_order") ?: @"Order unavailable"];
                        PPProNotificationTargetsComplete(NO, completion);
                        return;
                    }

                    PPDeliveryOrderModel *order = [PPDeliveryOrderModel fromDictionary:snapshot.data withID:snapshot.documentID];
                    if (!order) {
                        PPProNotificationTargetsComplete(NO, completion);
                        return;
                    }
                    PPDeliveryOrderDetailViewController *controller = [[PPDeliveryOrderDetailViewController alloc] initWithOrder:order];
                    controller.hidesBottomBarWhenPushed = YES;
                    [navigationController pushViewController:controller animated:YES];
                    PPProNotificationTargetsComplete(YES, completion);
                });
            }];
            return;
        }

        case PPProNotificationTargetKindChat: {
            NSString *threadID = PPProNotificationTargetsFirstStringForKeys(safePayload, @[@"conversationId", @"threadId", @"threadID"]);
            if (threadID.length == 0) {
                NSLog(@"[NotificationRoute] Chat payload missing threadId.");
                PPProNotificationTargetsComplete(NO, completion);
                return;
            }
            FIRDocumentReference *reference = [[[FIRFirestore firestore] collectionWithPath:@"Chats"] documentWithPath:threadID];
            [reference getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable snapshot, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error || !snapshot.exists || !snapshot.data) {
                        NSLog(@"[NotificationRoute] Chat fetch failed for %@: %@", threadID, error.localizedDescription ?: @"missing document");
                        [PPHUD showError:kLang(@"ch_provider_support_error") ?: @"Unable to load chat"];
                        PPProNotificationTargetsComplete(NO, completion);
                        return;
                    }

                    ChatThreadModel *thread = [[ChatThreadModel alloc] initWithDictionary:snapshot.data];
                    thread.ID = snapshot.documentID;
                    PPUserMessagesViewController *controller = [[PPUserMessagesViewController alloc] initWithChatThread:thread];
                    controller.hidesBottomBarWhenPushed = YES;
                    [navigationController pushViewController:controller animated:YES];
                    PPProNotificationTargetsComplete(YES, completion);
                });
            }];
            return;
        }

        case PPProNotificationTargetKindUnknown:
        default:
            NSLog(@"[NotificationRoute] Unsupported notification payload for direct routing. type=%@ route=%@",
                  PPProNotificationTargetsFirstStringForKeys(safePayload, @[@"notificationType", @"type", @"eventKey"]),
                  PPProNotificationTargetsTrimmedString(safePayload[@"route"]));
            if (presenter) {
                [PPToast toast:kLang(@"Notifications") ?: @"Notifications"
                         style:PPToastStyleInfo
                        haptic:NO
                      duration:1.4
                      position:PPToastPositionBottom
                        inView:presenter.view];
            }
            PPProNotificationTargetsComplete(NO, completion);
            return;
    }
}

@end
