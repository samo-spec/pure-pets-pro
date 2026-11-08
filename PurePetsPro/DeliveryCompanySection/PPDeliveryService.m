#import "PPDeliveryService.h"
#import "PPDeliveryCompanyService.h"
#import "PPDeliveryCompanyModels.h"
#import "PPFirebaseCompat.h"
#import <math.h>
#import "Firebase.h"
@import FirebaseFunctions;
@import FirebaseAuth;

NSString * const PPDeliveryServiceErrorDomain = @"PPDeliveryService";

#ifndef PP_FIREBASE_FUNCTIONS_ERROR_CONSTANTS_DEFINED
#define PP_FIREBASE_FUNCTIONS_ERROR_CONSTANTS_DEFINED
static NSString * const FIRFunctionsErrorDomain = @"com.firebase.functions";
static NSString * const FIRFunctionsErrorDetailsKey = @"details";
#endif

static NSDictionary *PPDeliveryDictionary(id value) {
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

static NSArray *PPDeliveryArray(id value) {
    return [value isKindOfClass:NSArray.class] ? value : @[];
}

static NSArray<NSString *> *PPDeliveryStringArray(id value) {
    NSMutableArray<NSString *> *strings = [NSMutableArray array];
    for (id entry in PPDeliveryArray(value)) {
        if ([entry isKindOfClass:NSString.class] && [(NSString *)entry length] > 0) {
            [strings addObject:entry];
        }
    }
    return strings.copy;
}

static NSString *PPDeliveryString(id value) {
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value isKindOfClass:NSNumber.class]) return [(NSNumber *)value stringValue];
    return @"";
}

static NSDate * _Nullable PPDeliveryDate(id value) {
    if ([value isKindOfClass:NSDate.class]) return value;
    if ([value isKindOfClass:FIRTimestamp.class]) return [(FIRTimestamp *)value dateValue];
    if ([value isKindOfClass:NSDictionary.class]) {
        id seconds = value[@"seconds"] ?: value[@"_seconds"];
        id nanoseconds = value[@"nanoseconds"] ?: value[@"_nanoseconds"] ?: @0;
        if (![seconds isKindOfClass:NSNumber.class] || ![nanoseconds isKindOfClass:NSNumber.class]) return nil;
        double secondsValue = [seconds doubleValue];
        double nanosValue = [nanoseconds doubleValue];
        if (!isfinite(secondsValue) || !isfinite(nanosValue) ||
            secondsValue < -62135596800.0 || secondsValue > 253402300799.0 ||
            nanosValue < 0 || nanosValue >= 1000000000.0) return nil;
        return [NSDate dateWithTimeIntervalSince1970:secondsValue + nanosValue / 1000000000.0];
    }
    if (![value isKindOfClass:NSString.class] || [(NSString *)value length] == 0) return nil;
    if (@available(iOS 10.0, *)) {
        NSISO8601DateFormatter *formatter = [NSISO8601DateFormatter new];
        if (@available(iOS 11.0, *)) {
            formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
            NSDate *date = [formatter dateFromString:value];
            if (date) return date;
            formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
        }
        return [formatter dateFromString:value];
    }
    return nil;
}

static NSError *PPDeliveryInvalidResponseError(void) {
    NSString *description = kLang(@"Delivery_Invalid_Response");
    if (description.length == 0 || [description isEqualToString:@"Delivery_Invalid_Response"]) {
        description = @"Delivery service returned an invalid response.";
    }
    return [NSError errorWithDomain:PPDeliveryServiceErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

static NSError *PPDeliveryCompanyContextError(void) {
    return [NSError errorWithDomain:PPDeliveryServiceErrorDomain code:2 userInfo:@{
        NSLocalizedDescriptionKey: kLang(@"DeliveryCompany_Setup_CompanyIDRequired"),
        @"details": @{@"domainCode": @"DELIVERY_COMPANY_NOT_CONFIGURED"}
    }];
}

@implementation PPDeliveryAllowedAction

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if ((self = [super init])) {
        NSDictionary *source = PPDeliveryDictionary(dictionary);
        _action = [PPDeliveryString(source[@"action"]) uppercaseString];
        _permission = PPDeliveryString(source[@"permission"]);
        _expectedRevision = [source[@"expectedRevision"] respondsToSelector:@selector(integerValue)]
            ? [source[@"expectedRevision"] integerValue]
            : -1;
        _expectedState = [PPDeliveryString(source[@"expectedState"]) lowercaseString];
    }
    return self;
}

@end


@implementation PPDeliveryRequestRecord

- (instancetype)initWithDictionary:(NSDictionary *)dictionary documentID:(NSString *)documentID {
    if ((self = [super init])) {
        NSDictionary *source = PPDeliveryDictionary(dictionary);
        _requestID = documentID.length > 0 ? documentID : PPDeliveryString(source[@"id"]);
        _orderID = PPDeliveryString(source[@"orderId"]);
        _orderNumber = PPDeliveryString(source[@"reference"]);
        if (_orderNumber.length == 0) _orderNumber = PPDeliveryString(source[@"orderNumber"]);
        _status = [PPDeliveryString(source[@"legacyStatus"]) lowercaseString];
        if (_status.length == 0) _status = [PPDeliveryString(source[@"status"]) lowercaseString];
        _authority = PPDeliveryString(source[@"authority"]);
        if (_authority.length == 0) {
            _authority = [source[@"fulfillmentVersion"] integerValue] == 1
                ? @"FULFILLMENT_V1"
                : @"COMPANY_DELIVERY_REQUEST";
        }
        _deliveryJobStatus = PPDeliveryString(source[@"deliveryJobStatus"]);
        _carrierAssignmentStatus = PPDeliveryString(source[@"carrierAssignmentStatus"]);
        _driverAssignmentStatus = PPDeliveryString(source[@"driverAssignmentStatus"]);
        _routeStatus = PPDeliveryString(source[@"routeStatus"]);
        _podStatus = PPDeliveryString(source[@"podStatus"]);
        _codStatus = PPDeliveryString(source[@"codStatus"]);
        _returnStatus = PPDeliveryString(source[@"returnStatus"]);
        _revision = MAX(0, [source[@"revision"] respondsToSelector:@selector(integerValue)]
                            ? [source[@"revision"] integerValue]
                            : 0);
        _carrierID = PPDeliveryString(source[@"carrierId"]);
        if (_carrierID.length == 0) _carrierID = PPDeliveryString(source[@"targetCompanyId"]);
        if (_carrierID.length == 0) _carrierID = PPDeliveryString(source[@"companyId"]);
        _carrierName = PPDeliveryString(source[@"carrierName"]);
        if (_carrierName.length == 0) _carrierName = PPDeliveryString(source[@"targetCompanyName"]);
        if (_carrierName.length == 0) _carrierName = PPDeliveryString(source[@"companyName"]);
        _carrierType = PPDeliveryString(source[@"carrierType"]);
        _customerName = PPDeliveryString(source[@"customerName"]);
        _assignedDriverUID = PPDeliveryString(source[@"assignedDriverUid"]);
        if (_assignedDriverUID.length == 0) _assignedDriverUID = PPDeliveryString(source[@"assignedDriverUID"]);
        _assignedDriverName = PPDeliveryString(source[@"assignedDriverName"]);
        _deliveryFee = [source[@"deliveryFee"] isKindOfClass:NSNumber.class] ? source[@"deliveryFee"] : nil;
        _pickupAddress = [PPDeliveryDictionary(source[@"pickupAddress"]) copy];
        _dropoffAddress = [PPDeliveryDictionary(source[@"dropoffAddress"]) copy];
        _proofOfDelivery = [PPDeliveryDictionary(source[@"pod"] ?: source[@"proofOfDelivery"]) copy];
        _cod = [PPDeliveryDictionary(source[@"cod"]) copy];

        NSMutableArray<PPDeliveryAllowedAction *> *actions = [NSMutableArray array];
        id rawActionsValue = source[@"allowedActions"];
        NSArray *rawActions = PPDeliveryArray(rawActionsValue);
        if ([rawActionsValue isKindOfClass:NSArray.class]) {
            for (id rawAction in rawActions) {
                if (![rawAction isKindOfClass:NSDictionary.class]) continue;
                PPDeliveryAllowedAction *action = [[PPDeliveryAllowedAction alloc] initWithDictionary:rawAction];
                if (action.action.length > 0 && action.expectedRevision >= 0 && action.expectedState.length > 0) {
                    [actions addObject:action];
                }
            }
        } else if ([_authority isEqualToString:@"COMPANY_DELIVERY_REQUEST"]) {
            // Legacy partner records may omit actions. An explicit server
            // denial ([]) and fulfillment authority must never be replaced.
            NSString *st = [_status lowercaseString];
            if ([st isEqualToString:@"offered"] || [st isEqualToString:@"pending"]) {
                [actions addObject:[[PPDeliveryAllowedAction alloc] initWithDictionary:@{@"action": @"ACCEPT", @"expectedRevision": @(_revision), @"expectedState": st}]];
                [actions addObject:[[PPDeliveryAllowedAction alloc] initWithDictionary:@{@"action": @"REJECT", @"expectedRevision": @(_revision), @"expectedState": st}]];
            } else if ([st isEqualToString:@"accepted"] || [st isEqualToString:@"accepted_by_company"]) {
                [actions addObject:[[PPDeliveryAllowedAction alloc] initWithDictionary:@{@"action": @"ASSIGN", @"expectedRevision": @(_revision), @"expectedState": st}]];
                [actions addObject:[[PPDeliveryAllowedAction alloc] initWithDictionary:@{@"action": @"CANCEL", @"expectedRevision": @(_revision), @"expectedState": st}]];
            } else if ([st isEqualToString:@"assigned"] || [st isEqualToString:@"assigned_to_driver"]) {
                [actions addObject:[[PPDeliveryAllowedAction alloc] initWithDictionary:@{@"action": @"REASSIGN", @"expectedRevision": @(_revision), @"expectedState": st}]];
                [actions addObject:[[PPDeliveryAllowedAction alloc] initWithDictionary:@{@"action": @"CANCEL", @"expectedRevision": @(_revision), @"expectedState": st}]];
            } else if ([st isEqualToString:@"picked_up"] || [st isEqualToString:@"in_transit"] || [st isEqualToString:@"delivered"]) {
                [actions addObject:[[PPDeliveryAllowedAction alloc] initWithDictionary:@{@"action": @"COMPLETE", @"expectedRevision": @(_revision), @"expectedState": st}]];
            }
        }
        _allowedActions = actions.copy;
        _createdAt = PPDeliveryDate(source[@"createdAt"]);
        _updatedAt = PPDeliveryDate(source[@"updatedAt"]);
    }
    return self;
}

- (PPDeliveryAllowedAction * _Nullable)allowedActionNamed:(NSString *)action {
    NSString *target = [action.uppercaseString copy];
    for (PPDeliveryAllowedAction *candidate in self.allowedActions) {
        if ([candidate.action isEqualToString:target]) return candidate;
    }
    return nil;
}

@end


@implementation PPDeliveryDriverRecord

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if ((self = [super init])) {
        NSDictionary *source = PPDeliveryDictionary(dictionary);
        _uid = PPDeliveryString(source[@"uid"]);
        _displayName = PPDeliveryString(source[@"displayName"]);
        if (_displayName.length == 0) _displayName = PPDeliveryString(source[@"name"]);
        _phone = PPDeliveryString(source[@"phone"]);
        _accountStatus = PPDeliveryString(source[@"accountStatus"] ?: source[@"status"]);
        _presence = PPDeliveryString(source[@"presence"]);
        if (_presence.length == 0) {
            _presence = [source[@"online"] boolValue] ? @"online" : @"offline";
        }
        _shiftStatus = PPDeliveryString(source[@"shiftStatus"]);
        _workState = PPDeliveryString(source[@"workState"]);
        _canReceiveAssignments = [source[@"canReceiveAssignments"] respondsToSelector:@selector(boolValue)]
            ? [source[@"canReceiveAssignments"] boolValue]
            : [source[@"available"] boolValue];
        _activeDeliveryCount = [source[@"activeDeliveryCount"] respondsToSelector:@selector(integerValue)]
            ? [source[@"activeDeliveryCount"] integerValue]
            : [source[@"activeDeliveriesCount"] integerValue];
        _maxConcurrentDeliveries = [source[@"maxConcurrentDeliveries"] isKindOfClass:NSNumber.class]
            ? source[@"maxConcurrentDeliveries"]
            : nil;
        _revision = MAX(0, [source[@"revision"] respondsToSelector:@selector(integerValue)]
                            ? [source[@"revision"] integerValue]
                            : 0);
        // Server shape is eligibility { eligible, reasonCodes, evidence }. A
        // missing verdict is not eligibility: fail closed.
        NSDictionary *eligibility = PPDeliveryDictionary(source[@"eligibility"]);
        id eligibleValue = eligibility[@"eligible"] ?: source[@"eligible"];
        _eligible = [eligibleValue respondsToSelector:@selector(boolValue)] ? [eligibleValue boolValue] : NO;
        _eligibilityReasonCodes = PPDeliveryStringArray(eligibility[@"reasonCodes"] ?: source[@"eligibilityReasonCodes"]);
        _eligibilityEvidence = [PPDeliveryDictionary(eligibility[@"evidence"] ?: source[@"eligibilityEvidence"]) copy];
    }
    return self;
}

@end


@implementation PPDeliveryCompanyMemberRecord

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if ((self = [super init])) {
        NSDictionary *source = PPDeliveryDictionary(dictionary);
        _uid = PPDeliveryString(source[@"uid"]);
        _displayName = PPDeliveryString(source[@"displayName"] ?: source[@"name"]);
        _phone = PPDeliveryString(source[@"phone"]);
        _email = PPDeliveryString(source[@"email"]);
        _photoURL = PPDeliveryString(source[@"photoURL"]);
        _role = PPDeliveryString(source[@"role"]);
        _status = PPDeliveryString(source[@"status"]);
        _online = [source[@"online"] boolValue];
        _available = [source[@"available"] boolValue];
        _canReceiveAssignments = [source[@"canReceiveAssignments"] boolValue];
        _activeDeliveryCount = [source[@"activeDeliveryCount"] integerValue];
        _revision = [source[@"revision"] integerValue];
        _lastSeenAt = PPDeliveryDate(source[@"lastSeenAt"]);
    }
    return self;
}

@end


@implementation PPDeliveryVehicleRecord

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if ((self = [super init])) {
        NSDictionary *source = PPDeliveryDictionary(dictionary);
        _vehicleID = PPDeliveryString(source[@"id"]);
        _label = PPDeliveryString(source[@"label"]);
        _plate = PPDeliveryString(source[@"plate"]);
        _type = PPDeliveryString(source[@"type"]);
        _status = PPDeliveryString(source[@"status"]);
        _capacity = [PPDeliveryDictionary(source[@"capacity"]) copy];
        _driverUID = PPDeliveryString(source[@"driverUid"]);
        _hubID = PPDeliveryString(source[@"hubId"]);
        _compliance = [PPDeliveryDictionary(source[@"compliance"]) copy];
    }
    return self;
}

@end


@implementation PPDeliveryHubRecord

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if ((self = [super init])) {
        NSDictionary *source = PPDeliveryDictionary(dictionary);
        _hubID = PPDeliveryString(source[@"id"]);
        _name = PPDeliveryString(source[@"name"]);
        _status = PPDeliveryString(source[@"status"]);
        _location = [PPDeliveryDictionary(source[@"location"]) copy];
        _zoneIDs = PPDeliveryStringArray(source[@"zoneIds"]);
        _capabilities = [PPDeliveryDictionary(source[@"capabilities"]) copy];
    }
    return self;
}

@end


@implementation PPDeliveryServiceZoneRecord

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if ((self = [super init])) {
        NSDictionary *source = PPDeliveryDictionary(dictionary);
        _zoneID = PPDeliveryString(source[@"id"]);
        _name = PPDeliveryString(source[@"name"]);
        _status = PPDeliveryString(source[@"status"]);
        _boundary = [PPDeliveryDictionary(source[@"boundary"]) copy];
        _hubIDs = PPDeliveryStringArray(source[@"hubIds"]);
        _capabilities = [PPDeliveryDictionary(source[@"capabilities"]) copy];
    }
    return self;
}

@end


@implementation PPDeliveryDriverShiftRecord

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if ((self = [super init])) {
        NSDictionary *source = PPDeliveryDictionary(dictionary);
        _shiftID = PPDeliveryString(source[@"id"]);
        _driverUID = PPDeliveryString(source[@"driverUid"]);
        _status = PPDeliveryString(source[@"status"]);
        _plannedStartAt = PPDeliveryDate(source[@"plannedStartAt"]);
        _plannedEndAt = PPDeliveryDate(source[@"plannedEndAt"]);
        _actualStartAt = PPDeliveryDate(source[@"actualStartAt"]);
        _actualEndAt = PPDeliveryDate(source[@"actualEndAt"]);
        _revision = [source[@"revision"] integerValue];
    }
    return self;
}

@end


@implementation PPDeliveryRouteStopRecord

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if ((self = [super init])) {
        NSDictionary *source = PPDeliveryDictionary(dictionary);
        _stopID = PPDeliveryString(source[@"id"]);
        _routeID = PPDeliveryString(source[@"routeId"]);
        _deliveryJobID = PPDeliveryString(source[@"deliveryJobId"]);
        _sequence = [source[@"sequence"] integerValue];
        _type = PPDeliveryString(source[@"type"]);
        _location = [PPDeliveryDictionary(source[@"location"]) copy];
        _timeWindow = [PPDeliveryDictionary(source[@"timeWindow"]) copy];
        _serviceDuration = [source[@"serviceDuration"] isKindOfClass:NSNumber.class] ? source[@"serviceDuration"] : nil;
        _status = PPDeliveryString(source[@"status"]);
        _plannedArrival = PPDeliveryDate(source[@"plannedArrival"]);
        _estimatedArrival = PPDeliveryDate(source[@"estimatedArrival"]);
        _actualArrival = PPDeliveryDate(source[@"actualArrival"]);
        _actualDeparture = PPDeliveryDate(source[@"actualDeparture"]);
    }
    return self;
}

@end


@implementation PPDeliveryRouteRecord

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if ((self = [super init])) {
        NSDictionary *source = PPDeliveryDictionary(dictionary);
        _routeID = PPDeliveryString(source[@"id"]);
        _carrierID = PPDeliveryString(source[@"carrierId"]);
        _driverUID = PPDeliveryString(source[@"driverUid"]);
        _vehicleID = PPDeliveryString(source[@"vehicleId"]);
        _hubID = PPDeliveryString(source[@"hubId"]);
        _status = PPDeliveryString(source[@"status"]);
        _plannedStartAt = PPDeliveryDate(source[@"plannedStartAt"]);
        _plannedEndAt = PPDeliveryDate(source[@"plannedEndAt"]);
        _actualStartAt = PPDeliveryDate(source[@"actualStartAt"]);
        _actualEndAt = PPDeliveryDate(source[@"actualEndAt"]);
        _stopCount = [source[@"stopCount"] integerValue];
        _completedStopCount = [source[@"completedStopCount"] integerValue];
        _distanceMeters = [source[@"distanceMeters"] isKindOfClass:NSNumber.class] ? source[@"distanceMeters"] : nil;
        _durationSeconds = [source[@"durationSeconds"] isKindOfClass:NSNumber.class] ? source[@"durationSeconds"] : nil;
        _capacity = [PPDeliveryDictionary(source[@"capacity"]) copy];
        _revision = [source[@"revision"] integerValue];

        NSMutableArray<PPDeliveryRouteStopRecord *> *stops = [NSMutableArray array];
        for (id rawStop in PPDeliveryArray(source[@"stops"])) {
            if (![rawStop isKindOfClass:NSDictionary.class]) continue;
            PPDeliveryRouteStopRecord *stop = [[PPDeliveryRouteStopRecord alloc] initWithDictionary:rawStop];
            if (stop.stopID.length > 0) [stops addObject:stop];
        }
        _stops = stops.copy;
    }
    return self;
}

@end


@implementation PPDeliveryFleetFoundation

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if ((self = [super init])) {
        NSDictionary *source = PPDeliveryDictionary(dictionary);
        _configurationState = PPDeliveryString(source[@"configurationState"]);
        _source = PPDeliveryString(source[@"source"]);

        NSMutableArray<PPDeliveryVehicleRecord *> *vehicles = [NSMutableArray array];
        for (id rawVehicle in PPDeliveryArray(source[@"vehicles"])) {
            if (![rawVehicle isKindOfClass:NSDictionary.class]) continue;
            PPDeliveryVehicleRecord *vehicle = [[PPDeliveryVehicleRecord alloc] initWithDictionary:rawVehicle];
            if (vehicle.vehicleID.length > 0) [vehicles addObject:vehicle];
        }
        _vehicles = vehicles.copy;

        NSMutableArray<PPDeliveryHubRecord *> *hubs = [NSMutableArray array];
        for (id rawHub in PPDeliveryArray(source[@"hubs"])) {
            if (![rawHub isKindOfClass:NSDictionary.class]) continue;
            PPDeliveryHubRecord *hub = [[PPDeliveryHubRecord alloc] initWithDictionary:rawHub];
            if (hub.hubID.length > 0) [hubs addObject:hub];
        }
        _hubs = hubs.copy;

        NSMutableArray<PPDeliveryServiceZoneRecord *> *zones = [NSMutableArray array];
        for (id rawZone in PPDeliveryArray(source[@"serviceZones"])) {
            if (![rawZone isKindOfClass:NSDictionary.class]) continue;
            PPDeliveryServiceZoneRecord *zone = [[PPDeliveryServiceZoneRecord alloc] initWithDictionary:rawZone];
            if (zone.zoneID.length > 0) [zones addObject:zone];
        }
        _serviceZones = zones.copy;

        NSMutableArray<PPDeliveryDriverShiftRecord *> *shifts = [NSMutableArray array];
        for (id rawShift in PPDeliveryArray(source[@"driverShifts"])) {
            if (![rawShift isKindOfClass:NSDictionary.class]) continue;
            PPDeliveryDriverShiftRecord *shift = [[PPDeliveryDriverShiftRecord alloc] initWithDictionary:rawShift];
            if (shift.shiftID.length > 0) [shifts addObject:shift];
        }
        _driverShifts = shifts.copy;

        NSMutableArray<PPDeliveryRouteRecord *> *routes = [NSMutableArray array];
        for (id rawRoute in PPDeliveryArray(source[@"routes"])) {
            if (![rawRoute isKindOfClass:NSDictionary.class]) continue;
            PPDeliveryRouteRecord *route = [[PPDeliveryRouteRecord alloc] initWithDictionary:rawRoute];
            if (route.routeID.length > 0) [routes addObject:route];
        }
        _routes = routes.copy;
    }
    return self;
}

@end


@implementation PPDeliveryExceptionRecord

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if ((self = [super init])) {
        NSDictionary *source = PPDeliveryDictionary(dictionary);
        _exceptionID = PPDeliveryString(source[@"id"]);
        _deliveryJobID = PPDeliveryString(source[@"deliveryJobId"]);
        _type = PPDeliveryString(source[@"type"]);
        _severity = PPDeliveryString(source[@"severity"]);
        _status = PPDeliveryString(source[@"status"]);
        _reasonCode = PPDeliveryString(source[@"reasonCode"]);
        _evidence = [PPDeliveryDictionary(source[@"evidence"]) copy];
        _createdAt = PPDeliveryDate(source[@"createdAt"]);
    }
    return self;
}

@end


@implementation PPDeliveryCommandCenterSnapshot

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if ((self = [super init])) {
        NSDictionary *source = PPDeliveryDictionary(dictionary);
        _carrier = [PPDeliveryDictionary(source[@"carrier"]) copy];

        NSMutableArray<PPDeliveryRequestRecord *> *records = [NSMutableArray array];
        for (id rawJob in PPDeliveryArray(source[@"jobs"])) {
            if (![rawJob isKindOfClass:NSDictionary.class]) continue;
            PPDeliveryRequestRecord *record = [[PPDeliveryRequestRecord alloc] initWithDictionary:rawJob
                                                                                       documentID:PPDeliveryString(rawJob[@"id"])];
            if (record.requestID.length > 0) [records addObject:record];
        }
        _records = records.copy;

        NSMutableArray<PPDeliveryDriverRecord *> *drivers = [NSMutableArray array];
        for (id rawDriver in PPDeliveryArray(source[@"drivers"])) {
            if (![rawDriver isKindOfClass:NSDictionary.class]) continue;
            PPDeliveryDriverRecord *driver = [[PPDeliveryDriverRecord alloc] initWithDictionary:rawDriver];
            if (driver.uid.length > 0) [drivers addObject:driver];
        }
        _drivers = drivers.copy;

        NSMutableArray<PPDeliveryExceptionRecord *> *exceptions = [NSMutableArray array];
        for (id rawException in PPDeliveryArray(source[@"exceptions"])) {
            if (![rawException isKindOfClass:NSDictionary.class]) continue;
            PPDeliveryExceptionRecord *exception = [[PPDeliveryExceptionRecord alloc] initWithDictionary:rawException];
            if (exception.exceptionID.length > 0) [exceptions addObject:exception];
        }
        _exceptions = exceptions.copy;
        _projection = [PPDeliveryDictionary(source[@"projection"]) copy];
        _fleet = [[PPDeliveryFleetFoundation alloc] initWithDictionary:PPDeliveryDictionary(source[@"fleet"])];
        _capabilities = [PPDeliveryDictionary(source[@"capabilities"]) copy];
        _permissions = PPDeliveryStringArray(source[@"permissions"]);
        _permissionSource = PPDeliveryString(source[@"permissionSource"]);
        _eligibilityContext = [PPDeliveryDictionary(source[@"eligibilityContext"]) copy];
    }
    return self;
}

@end


@implementation PPDeliveryDossierSnapshot

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if ((self = [super init])) {
        NSDictionary *source = PPDeliveryDictionary(dictionary);
        NSDictionary *job = PPDeliveryDictionary(source[@"job"]);
        _record = [[PPDeliveryRequestRecord alloc] initWithDictionary:job
                                                           documentID:PPDeliveryString(job[@"id"])];
        _carrier = [PPDeliveryDictionary(source[@"carrier"]) copy];

        NSMutableArray<NSDictionary *> *eventList = [NSMutableArray array];
        for (id rawEvent in PPDeliveryArray(source[@"events"])) {
            if ([rawEvent isKindOfClass:NSDictionary.class]) [eventList addObject:rawEvent];
        }
        _events = eventList.copy;

        NSMutableArray<PPDeliveryDriverRecord *> *drivers = [NSMutableArray array];
        for (id rawDriver in PPDeliveryArray(source[@"drivers"])) {
            if (![rawDriver isKindOfClass:NSDictionary.class]) continue;
            PPDeliveryDriverRecord *driver = [[PPDeliveryDriverRecord alloc] initWithDictionary:rawDriver];
            if (driver.uid.length > 0) [drivers addObject:driver];
        }
        _drivers = drivers.copy;
        _availabilityFunnel = [PPDeliveryDictionary(source[@"availabilityFunnel"]) copy];
        _freshness = [PPDeliveryDictionary(source[@"freshness"]) copy];
    }
    return self;
}

@end


@implementation PPDeliveryCommandResult

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if ((self = [super init])) {
        NSDictionary *source = PPDeliveryDictionary(dictionary);
        _commandID = PPDeliveryString(source[@"commandId"]);
        _requestID = PPDeliveryString(source[@"requestId"]);
        _action = PPDeliveryString(source[@"action"]);
        _status = PPDeliveryString(source[@"status"]);
        _revision = [source[@"revision"] integerValue];
        _outcome = PPDeliveryString(source[@"outcome"] ?: source[@"result"]);
    }
    return self;
}

@end


@interface PPDeliveryService ()
@property (nonatomic, copy, readwrite, nullable) NSString *currentCompanyID;
- (void)executeCanonicalAllowedAction:(PPDeliveryAllowedAction *)allowedAction
                           requestID:(NSString *)requestID
                           commandID:(NSString *)commandID
                           driverUID:(NSString *)driverUID
                   handoverConfirmed:(BOOL)handoverConfirmed
                              reason:(NSString *)reason
                          completion:(void(^)(PPDeliveryCommandResult *, NSError *))completion;
- (void)callFunction:(NSString *)name
              params:(NSDictionary *)params
          completion:(void(^)(id _Nullable result, NSError * _Nullable error))completion;
@end

@implementation PPDeliveryService

+ (instancetype)shared {
    static PPDeliveryService *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [self new]; });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _currentCompanyID = nil;
    }
    return self;
}

- (void)setCurrentCompanyID:(NSString *)companyID {
    _currentCompanyID = [companyID copy];
}

- (NSString *)effectiveCompanyID {
    if (self.currentCompanyID.length > 0) return self.currentCompanyID;
    PPDeliveryCompanyProfile *profile = [PPDeliveryCompanyService shared].verifiedProfile;
    if (profile.companyID.length > 0) return profile.companyID;
    return [PPDeliveryCompanyService shared].configuredCompanyID ?: @"";
}

- (void)callFunction:(NSString *)name
              params:(NSDictionary *)params
          completion:(void(^)(id _Nullable result, NSError * _Nullable error))completion {
    FIRFunctions *functions = [FIRFunctions functionsForRegion:@"us-central1"];
    FIRHTTPSCallable *callable = [functions HTTPSCallableWithName:name];
    callable.timeoutInterval = 30.0;
    [callable callWithObject:params ?: @{} completion:^(FIRHTTPSCallableResult *result, NSError *error) {
        if (completion) completion(result.data, error);
    }];
}

+ (NSDictionary<NSString *,id> *)domainDetailsForError:(NSError *)error {
    NSError *current = error;
    for (NSUInteger depth = 0; current && depth < 8; depth++) {
        id details = current.userInfo[FIRFunctionsErrorDetailsKey] ?: current.userInfo[@"details"];
        if ([details isKindOfClass:NSDictionary.class] && PPDeliveryString(details[@"domainCode"]).length > 0) return details;
        id underlying = current.userInfo[NSUnderlyingErrorKey];
        current = [underlying isKindOfClass:NSError.class] && underlying != current ? underlying : nil;
    }
    return @{};
}

+ (NSString *)domainCodeForError:(NSError *)error {
    NSString *domainCode = PPDeliveryString([self domainDetailsForError:error][@"domainCode"]);
    if (domainCode.length > 0) return domainCode;
    if ([self isPermissionError:error]) return @"DELIVERY_PERMISSION_DENIED";
    return @"DELIVERY_SERVICE_UNAVAILABLE";
}

+ (BOOL)isPermissionError:(NSError *)error {
    if (!error) return NO;
    NSString *domainCode = PPDeliveryString([self domainDetailsForError:error][@"domainCode"]);
    if ([domainCode isEqualToString:@"DELIVERY_PERMISSION_DENIED"]) return YES;
    NSError *current = error;
    for (NSUInteger depth = 0; current && depth < 8; depth++) {
        BOOL callableError = [current.domain isEqualToString:FIRFunctionsErrorDomain] ||
                             [current.domain isEqualToString:@"com.firebase.functions"] ||
                             [current.domain isEqualToString:@"PurePetsPro.DeliveryCompany"];
        if (callableError && (current.code == FIRFunctionsErrorCodePermissionDenied ||
                              current.code == FIRFunctionsErrorCodeUnauthenticated)) return YES;
        id underlying = current.userInfo[NSUnderlyingErrorKey];
        current = [underlying isKindOfClass:NSError.class] && underlying != current ? underlying : nil;
    }
    return NO;
}

#pragma mark - Command Center (Partner Dual Mode)

- (void)fetchCommandCenterWithCompletion:(void(^)(PPDeliveryCommandCenterSnapshot *, NSError *))completion {
    // Pro requires the current account's verified company. An absent profile
    // must not accidentally request the staff-only official-fleet dashboard.
    __weak typeof(self) weakSelf = self;
    [[PPDeliveryCompanyService shared] refreshConfiguredProfileWithCompletion:^(PPDeliveryCompanyProfile *profile, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (error || profile.companyID.length == 0) {
            if (completion) completion(nil, error ?: PPDeliveryCompanyContextError());
            return;
        }
        if (self.currentCompanyID.length > 0 && ![self.currentCompanyID isEqualToString:profile.companyID]) {
            if (completion) completion(nil, PPDeliveryCompanyContextError());
            return;
        }
        [self fetchVerifiedCommandCenterForProfile:profile completion:completion];
    }];
}

- (void)fetchVerifiedCommandCenterForProfile:(PPDeliveryCompanyProfile *)profile
                                completion:(void(^)(PPDeliveryCommandCenterSnapshot *, NSError *))completion {
    if (profile.isDriver) {
        [self fetchPartnerCommandCenterSnapshotWithCompletion:completion];
        return;
    }
    NSDictionary *params = @{@"pageSize": @100, @"companyId": profile.companyID};
    NSString *uid = [FIRAuth auth].currentUser.uid;

    __weak typeof(self) weakSelf = self;
    [self callFunction:@"getDeliveryCommandCenter"
                params:params
            completion:^(id result, NSError *error) {
        if (![[FIRAuth auth].currentUser.uid isEqualToString:uid] ||
            ![[PPDeliveryCompanyService shared].verifiedProfile.companyID isEqualToString:profile.companyID]) {
            if (completion) completion(nil, PPDeliveryCompanyContextError());
            return;
        }
        if (!error && [result isKindOfClass:NSDictionary.class] &&
            [result[@"jobs"] isKindOfClass:NSArray.class]) {
            if (completion) completion([[PPDeliveryCommandCenterSnapshot alloc] initWithDictionary:result], nil);
            return;
        }

        // A verified partner may use its company API when the staff API denies
        // staff access. Transport/malformed failures keep their original cause.
        if (error.code == FIRFunctionsErrorCodePermissionDenied && [PPDeliveryService isPermissionError:error]) {
            [weakSelf fetchPartnerCommandCenterSnapshotWithCompletion:completion];
        } else if (completion) {
            completion(nil, error ?: PPDeliveryInvalidResponseError());
        }
    }];
}

- (void)fetchPartnerCommandCenterSnapshotWithCompletion:(void(^)(PPDeliveryCommandCenterSnapshot *, NSError *))completion {
    PPDeliveryCompanyService *compService = [PPDeliveryCompanyService shared];
    PPDeliveryCompanyProfile *profile = compService.verifiedProfile;
    NSString *companyID = [self effectiveCompanyID];
    if (profile.companyID.length == 0 || ![profile.companyID isEqualToString:companyID]) {
        if (completion) completion(nil, PPDeliveryCompanyContextError());
        return;
    }

    [compService listRequestsForProfile:profile nextPageToken:nil completion:^(NSArray<PPDeliveryCompanyRequest *> * _Nullable requests, NSString * _Nullable nextPageToken, NSError * _Nullable reqError) {
        if (reqError) {
            if (completion) completion(nil, reqError);
            return;
        }

        [compService listMembersForCompanyID:companyID completion:^(NSArray<PPDeliveryCompanyMember *> * _Nullable members, NSError * _Nullable memError) {
            NSMutableArray *jobDicts = [NSMutableArray array];
            for (PPDeliveryCompanyRequest *req in requests ?: @[]) {
                NSMutableDictionary *dict = [NSMutableDictionary dictionary];
                dict[@"id"] = req.requestID ?: @"";
                dict[@"orderId"] = req.orderID ?: @"";
                dict[@"orderNumber"] = req.bestOrderNumber ?: @"";
                dict[@"reference"] = req.bestOrderNumber ?: @"";
                dict[@"status"] = req.status ?: @"pending";
                dict[@"legacyStatus"] = req.status ?: @"pending";
                dict[@"carrierId"] = req.companyID ?: companyID;
                dict[@"carrierName"] = req.companyName ?: (profile.name ?: @"");
                dict[@"assignedDriverUid"] = req.assignedDriverUID ?: @"";
                dict[@"assignedDriverName"] = req.assignedDriverName ?: @"";
                dict[@"deliveryFee"] = @(req.deliveryFee);
                dict[@"pickupAddress"] = req.pickupAddress ?: @{};
                dict[@"dropoffAddress"] = req.dropoffAddress ?: @{};
                dict[@"createdAt"] = req.createdAt ?: [NSDate date];
                dict[@"updatedAt"] = req.updatedAt ?: [NSDate date];
                dict[@"authority"] = @"COMPANY_DELIVERY_REQUEST";
                [jobDicts addObject:dict];
            }

            NSMutableArray *driverDicts = [NSMutableArray array];
            for (PPDeliveryCompanyMember *m in members ?: @[]) {
                // Only drivers can be assigned (assignCompanyDeliveryDriver).
                if (![m.role.lowercaseString isEqualToString:@"driver"]) continue;
                NSMutableDictionary *d = [NSMutableDictionary dictionary];
                d[@"uid"] = m.uid ?: @"";
                d[@"displayName"] = m.displayName ?: @"";
                d[@"phone"] = m.phone ?: @"";
                d[@"status"] = m.status ?: @"";
                d[@"presence"] = m.online ? @"online" : @"offline";
                d[@"canReceiveAssignments"] = @(m.canReceiveAssignments);
                d[@"activeDeliveryCount"] = @(m.activeDeliveryCount);
                // Only the blockers the server checks before assignment are
                // asserted here; the company eligibility policy is evaluated
                // by the backend when the command runs.
                NSMutableArray<NSString *> *reasons = [NSMutableArray array];
                if (![m.status.lowercaseString isEqualToString:@"active"]) [reasons addObject:@"ACCOUNT_NOT_ACTIVE"];
                if (!m.canReceiveAssignments) [reasons addObject:@"ASSIGNMENTS_PAUSED"];
                d[@"eligibility"] = @{ @"eligible": @(reasons.count == 0), @"reasonCodes": reasons.copy, @"evidence": @{} };
                [driverDicts addObject:d];
            }

            NSDictionary *carrierDict = @{
                @"id": companyID ?: @"",
                @"name": profile.name ?: (requests.firstObject.companyName ?: @""),
                @"status": profile.status ?: @"",
                @"role": profile.role ?: @""
            };

            // Permissions mirror the server-projected workspace capabilities;
            // nothing is granted by default.
            NSMutableArray<NSString *> *perms = [NSMutableArray array];
            if (profile.hasServerWorkspaceProjection) {
                if ([profile serverAllowsCapability:@"viewAllDeliveries"]) [perms addObject:@"delivery.view"];
                if ([profile serverAllowsCapability:@"assignDrivers"]) [perms addObject:@"delivery.assign"];
                if ([profile serverAllowsCapability:@"completeDeliveries"]) [perms addObject:@"delivery.complete"];
                if ([profile serverAllowsCapability:@"cancelRequests"]) [perms addObject:@"delivery.cancel"];
            } else if (profile.canDispatch) {
                [perms addObjectsFromArray:@[@"delivery.view", @"delivery.assign", @"delivery.complete", @"delivery.cancel"]];
            } else if (profile.isViewer) {
                [perms addObject:@"delivery.view"];
            }
            NSDictionary *payload = @{
                @"carrier": carrierDict,
                @"jobs": jobDicts,
                @"drivers": driverDicts,
                @"exceptions": @[],
                @"permissions": perms.copy,
                @"projection": @{
                    @"activeCount": @(requests.count),
                    @"driverCount": @(driverDicts.count)
                }
            };

            if (completion) completion([[PPDeliveryCommandCenterSnapshot alloc] initWithDictionary:payload], nil);
        }];
    }];
}

#pragma mark - Dossier (Partner Dual Mode)

- (void)fetchDossierForRequestID:(NSString *)requestID
                      completion:(void(^)(PPDeliveryDossierSnapshot *, NSError *))completion {
    NSString *safeRequestID = [requestID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (safeRequestID.length == 0) {
        if (completion) completion(nil, PPDeliveryInvalidResponseError());
        return;
    }

    PPDeliveryCompanyProfile *profile = [PPDeliveryCompanyService shared].verifiedProfile;
    NSString *companyID = [self effectiveCompanyID];
    if (profile.companyID.length == 0 || ![profile.companyID isEqualToString:companyID]) {
        if (completion) completion(nil, PPDeliveryCompanyContextError());
        return;
    }
    if (profile.isDriver) {
        [self fetchPartnerDossierForRequestID:safeRequestID completion:completion];
        return;
    }
    NSDictionary *params = @{@"requestId": safeRequestID, @"companyId": companyID};
    NSString *uid = [FIRAuth auth].currentUser.uid;

    __weak typeof(self) weakSelf = self;
    [self callFunction:@"getDeliveryDossier" params:params completion:^(id result, NSError *error) {
        if (![[FIRAuth auth].currentUser.uid isEqualToString:uid] ||
            ![[PPDeliveryCompanyService shared].verifiedProfile.companyID isEqualToString:companyID]) {
            if (completion) completion(nil, PPDeliveryCompanyContextError());
            return;
        }
        if (!error && [result isKindOfClass:NSDictionary.class] && result[@"job"]) {
            if (completion) completion([[PPDeliveryDossierSnapshot alloc] initWithDictionary:result], nil);
            return;
        }

        if (error.code == FIRFunctionsErrorCodePermissionDenied && [PPDeliveryService isPermissionError:error]) {
            [weakSelf fetchPartnerDossierForRequestID:safeRequestID completion:completion];
        } else if (completion) {
            completion(nil, error ?: PPDeliveryInvalidResponseError());
        }
    }];
}

- (void)fetchPartnerDossierForRequestID:(NSString *)requestID
                             completion:(void(^)(PPDeliveryDossierSnapshot *, NSError *))completion {
    PPDeliveryCompanyService *compService = [PPDeliveryCompanyService shared];
    NSString *companyID = [self effectiveCompanyID];
    if (compService.verifiedProfile.companyID.length == 0 || ![compService.verifiedProfile.companyID isEqualToString:companyID]) {
        if (completion) completion(nil, PPDeliveryCompanyContextError());
        return;
    }

    [compService getRequestWithID:requestID completion:^(PPDeliveryCompanyRequest * _Nullable req, NSError * _Nullable reqError) {
        if (reqError || !req) {
            if (completion) completion(nil, reqError ?: PPDeliveryInvalidResponseError());
            return;
        }

        [compService listMembersForCompanyID:companyID completion:^(NSArray<PPDeliveryCompanyMember *> * _Nullable members, NSError * _Nullable memError) {
            NSMutableDictionary *jobDict = [NSMutableDictionary dictionary];
            jobDict[@"id"] = req.requestID ?: @"";
            jobDict[@"orderId"] = req.orderID ?: @"";
            jobDict[@"orderNumber"] = req.bestOrderNumber ?: @"";
            jobDict[@"reference"] = req.bestOrderNumber ?: @"";
            jobDict[@"status"] = req.status ?: @"pending";
            jobDict[@"legacyStatus"] = req.status ?: @"pending";
            jobDict[@"carrierId"] = req.companyID ?: companyID;
            jobDict[@"carrierName"] = req.companyName ?: @"";
            jobDict[@"assignedDriverUid"] = req.assignedDriverUID ?: @"";
            jobDict[@"assignedDriverName"] = req.assignedDriverName ?: @"";
            jobDict[@"deliveryFee"] = @(req.deliveryFee);
            jobDict[@"pickupAddress"] = req.pickupAddress ?: @{};
            jobDict[@"dropoffAddress"] = req.dropoffAddress ?: @{};
            jobDict[@"createdAt"] = req.createdAt ?: [NSDate date];
            jobDict[@"updatedAt"] = req.updatedAt ?: [NSDate date];
            jobDict[@"authority"] = @"COMPANY_DELIVERY_REQUEST";

            NSMutableArray *events = [NSMutableArray array];
            for (PPDeliveryCompanyEvent *ev in req.events ?: @[]) {
                NSMutableDictionary *evD = [NSMutableDictionary dictionary];
                evD[@"id"] = ev.eventID ?: @"";
                evD[@"type"] = ev.eventType ?: @"status_change";
                evD[@"fromStatus"] = ev.fromStatus ?: @"";
                evD[@"toStatus"] = ev.toStatus ?: @"";
                evD[@"actorName"] = ev.actorName ?: @"";
                evD[@"actorRole"] = ev.actorRole ?: @"";
                evD[@"createdAt"] = ev.createdAt ?: [NSDate date];
                [events addObject:evD];
            }

            NSMutableArray *driverDicts = [NSMutableArray array];
            for (PPDeliveryCompanyMember *m in members ?: @[]) {
                // Only drivers can be assigned (assignCompanyDeliveryDriver);
                // owners and dispatchers are never offered as drivers.
                if (![m.role.lowercaseString isEqualToString:@"driver"]) continue;
                NSMutableDictionary *d = [NSMutableDictionary dictionary];
                d[@"uid"] = m.uid ?: @"";
                d[@"displayName"] = m.displayName ?: @"";
                d[@"phone"] = m.phone ?: @"";
                d[@"status"] = m.status ?: @"";
                d[@"presence"] = m.online ? @"online" : @"offline";
                d[@"canReceiveAssignments"] = @(m.canReceiveAssignments);
                d[@"activeDeliveryCount"] = @(m.activeDeliveryCount);
                // Same rule as the command-center fallback: only the blockers
                // the server checks are asserted; the backend decides the rest.
                NSMutableArray<NSString *> *reasons = [NSMutableArray array];
                if (![m.status.lowercaseString isEqualToString:@"active"]) [reasons addObject:@"ACCOUNT_NOT_ACTIVE"];
                if (!m.canReceiveAssignments) [reasons addObject:@"ASSIGNMENTS_PAUSED"];
                d[@"eligibility"] = @{ @"eligible": @(reasons.count == 0), @"reasonCodes": reasons.copy, @"evidence": @{} };
                [driverDicts addObject:d];
            }

            NSDictionary *dossierPayload = @{
                @"job": jobDict,
                @"carrier": @{@"id": companyID ?: @"", @"name": req.companyName ?: @""},
                @"events": events,
                @"drivers": driverDicts,
                @"freshness": @{@"loadedAt": [NSDate date]}
            };

            if (completion) completion([[PPDeliveryDossierSnapshot alloc] initWithDictionary:dossierPayload], nil);
        }];
    }];
}

#pragma mark - Command Execution (Partner Dual Mode)

- (void)executeAllowedAction:(PPDeliveryAllowedAction *)allowedAction
                   requestID:(NSString *)requestID
                   commandID:(NSString *)commandID
                   driverUID:(NSString *)driverUID
           handoverConfirmed:(BOOL)handoverConfirmed
                      reason:(NSString *)reason
                  completion:(void(^)(PPDeliveryCommandResult *, NSError *))completion {
    NSString *safeRequestID = [requestID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *safeCommandID = [commandID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (safeRequestID.length == 0 || safeCommandID.length == 0 ||
        allowedAction.action.length == 0) {
        if (completion) completion(nil, PPDeliveryInvalidResponseError());
        return;
    }

    NSString *act = [allowedAction.action uppercaseString];
    PPDeliveryCompanyService *compService = [PPDeliveryCompanyService shared];

    // Fulfillment acceptance is one server-owned transaction. Its document ID
    // belongs to FulfillmentOrders, never to the company-request collection.
    if ([act isEqualToString:@"ACCEPT_AND_ASSIGN"]) {
        NSString *targetDriver = [driverUID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (targetDriver.length == 0 || allowedAction.expectedRevision < 0 ||
            ![allowedAction.expectedState isEqualToString:@"delivery_requested"]) {
            if (completion) completion(nil, PPDeliveryInvalidResponseError());
            return;
        }
        [self executeCanonicalAllowedAction:allowedAction requestID:safeRequestID commandID:safeCommandID
                                 driverUID:targetDriver handoverConfirmed:handoverConfirmed reason:reason completion:completion];
        return;
    }

    // Delegate directly to partner-authorized actions
    if ([act isEqualToString:@"ASSIGN"] || [act isEqualToString:@"REASSIGN"]) {
        NSString *targetDriver = [driverUID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (targetDriver.length == 0) {
            if (completion) completion(nil, PPDeliveryInvalidResponseError());
            return;
        }
        BOOL isReassign = [act isEqualToString:@"REASSIGN"];
        void (^assignBlock)(NSDictionary *, NSError *) = ^(NSDictionary *res, NSError *err) {
            if (err) {
                if (completion) completion(nil, err);
                return;
            }
            NSDictionary *resultDict = @{
                @"commandId": safeCommandID,
                @"requestId": safeRequestID,
                @"action": act,
                @"status": @"assigned",
                @"revision": @(allowedAction.expectedRevision + 1),
                @"outcome": @"APPLIED"
            };
            if (completion) completion([[PPDeliveryCommandResult alloc] initWithDictionary:resultDict], nil);
        };
        if (isReassign) {
            [compService reassignRequestID:safeRequestID driverUID:targetDriver completion:assignBlock];
        } else {
            [compService assignRequestID:safeRequestID driverUID:targetDriver completion:assignBlock];
        }
        return;
    }

    if ([act isEqualToString:@"ACCEPT"]) {
        [compService acceptRequestID:safeRequestID completion:^(NSDictionary * _Nullable result, NSError * _Nullable error) {
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            NSDictionary *resultDict = @{
                @"commandId": safeCommandID,
                @"requestId": safeRequestID,
                @"action": act,
                @"status": @"accepted",
                @"revision": @(allowedAction.expectedRevision + 1),
                @"outcome": @"APPLIED"
            };
            if (completion) completion([[PPDeliveryCommandResult alloc] initWithDictionary:resultDict], nil);
        }];
        return;
    }

    if ([act isEqualToString:@"REJECT"]) {
        [compService rejectRequestID:safeRequestID reason:reason completion:^(NSDictionary * _Nullable result, NSError * _Nullable error) {
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            NSDictionary *resultDict = @{
                @"commandId": safeCommandID,
                @"requestId": safeRequestID,
                @"action": act,
                @"status": @"rejected",
                @"revision": @(allowedAction.expectedRevision + 1),
                @"outcome": @"APPLIED"
            };
            if (completion) completion([[PPDeliveryCommandResult alloc] initWithDictionary:resultDict], nil);
        }];
        return;
    }

    if ([act isEqualToString:@"COMPLETE"]) {
        [compService completeRequestID:safeRequestID completion:^(NSDictionary * _Nullable result, NSError * _Nullable error) {
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            NSDictionary *resultDict = @{
                @"commandId": safeCommandID,
                @"requestId": safeRequestID,
                @"action": act,
                @"status": @"completed",
                @"revision": @(allowedAction.expectedRevision + 1),
                @"outcome": @"APPLIED"
            };
            if (completion) completion([[PPDeliveryCommandResult alloc] initWithDictionary:resultDict], nil);
        }];
        return;
    }

    if ([act isEqualToString:@"CANCEL"]) {
        [compService cancelRequestID:safeRequestID reason:reason completion:^(NSDictionary * _Nullable result, NSError * _Nullable error) {
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            NSDictionary *resultDict = @{
                @"commandId": safeCommandID,
                @"requestId": safeRequestID,
                @"action": act,
                @"status": @"cancelled",
                @"revision": @(allowedAction.expectedRevision + 1),
                @"outcome": @"APPLIED"
            };
            if (completion) completion([[PPDeliveryCommandResult alloc] initWithDictionary:resultDict], nil);
        }];
        return;
    }

    [self executeCanonicalAllowedAction:allowedAction requestID:safeRequestID commandID:safeCommandID
                             driverUID:driverUID handoverConfirmed:handoverConfirmed reason:reason completion:completion];
}

- (void)executeCanonicalAllowedAction:(PPDeliveryAllowedAction *)allowedAction
                           requestID:(NSString *)requestID
                           commandID:(NSString *)commandID
                           driverUID:(NSString *)driverUID
                   handoverConfirmed:(BOOL)handoverConfirmed
                              reason:(NSString *)reason
                          completion:(void(^)(PPDeliveryCommandResult *, NSError *))completion {
    NSMutableDictionary *payload = [@{
        @"requestId": requestID,
        @"commandId": commandID,
        @"action": allowedAction.action,
        @"expectedRevision": @(allowedAction.expectedRevision),
        @"expectedState": allowedAction.expectedState ?: @"",
    } mutableCopy];
    if (driverUID.length > 0) payload[@"driverUid"] = driverUID;
    if (reason.length > 0) payload[@"reason"] = reason;
    if ([allowedAction.action isEqualToString:@"RECONCILE_COD"]) {
        payload[@"handoverConfirmed"] = @(handoverConfirmed);
    }

    [self callFunction:@"executeDeliveryCommand" params:payload completion:^(id result, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        if (![result isKindOfClass:NSDictionary.class]) {
            if (completion) completion(nil, PPDeliveryInvalidResponseError());
            return;
        }
        if (completion) completion([[PPDeliveryCommandResult alloc] initWithDictionary:result], nil);
    }];
}

- (void)executeDriverAction:(NSString *)action
                  driverUID:(NSString *)driverUID
           expectedRevision:(NSInteger)expectedRevision
                  commandID:(NSString *)commandID
                 completion:(void(^)(NSError *))completion {
    NSString *safeAction = [[action stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    NSString *safeDriverUID = [driverUID stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (safeDriverUID.length == 0) {
        if (completion) completion(PPDeliveryInvalidResponseError());
        return;
    }

    // Partner driver availability toggle
    if ([safeAction isEqualToString:@"PAUSE"] || [safeAction isEqualToString:@"SUSPEND"]) {
        [[PPDeliveryCompanyService shared] disableMemberUID:safeDriverUID companyID:[self effectiveCompanyID] completion:^(NSDictionary * _Nullable res, NSError * _Nullable err) {
            if (completion) completion(err);
        }];
        return;
    }

    // Canonical callable attempt
    [self callFunction:@"updateDeliveryDriverOperationalState"
                params:@{
                    @"action": safeAction,
                    @"driverUid": safeDriverUID,
                    @"expectedRevision": @(expectedRevision),
                    @"commandId": commandID ?: NSUUID.UUID.UUIDString
                }
            completion:^(__unused id result, NSError *error) {
        if (completion) completion(error);
    }];
}

#pragma mark - Member Management (Partner Backed)

- (void)fetchCompanyMembersForCompanyID:(NSString *)companyID
                             completion:(void(^)(NSArray<PPDeliveryCompanyMemberRecord *> *, NSError *))completion {
    NSString *cid = companyID.length > 0 ? companyID : [self effectiveCompanyID];
    [[PPDeliveryCompanyService shared] listMembersForCompanyID:cid completion:^(NSArray<PPDeliveryCompanyMember *> * _Nullable members, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        NSMutableArray<PPDeliveryCompanyMemberRecord *> *records = [NSMutableArray array];
        for (PPDeliveryCompanyMember *m in members ?: @[]) {
            NSDictionary *dict = @{
                @"uid": m.uid ?: @"",
                @"name": m.displayName ?: @"",
                @"displayName": m.displayName ?: @"",
                @"phone": m.phone ?: @"",
                @"email": m.email ?: @"",
                @"role": m.role ?: @"driver",
                @"status": m.status ?: @"active",
                @"online": @(m.online),
                @"available": @(m.available),
                @"canReceiveAssignments": @(m.available),
                @"activeDeliveryCount": @(m.activeDeliveryCount)
            };
            [records addObject:[[PPDeliveryCompanyMemberRecord alloc] initWithDictionary:dict]];
        }
        if (completion) completion(records.copy, nil);
    }];
}

- (void)inviteDriverIdentifier:(NSString *)identifier
                     companyID:(NSString *)companyID
                    completion:(void(^)(NSError *))completion {
    NSString *cid = companyID.length > 0 ? companyID : [self effectiveCompanyID];
    [[PPDeliveryCompanyService shared] inviteMemberIdentifier:identifier role:@"driver" companyID:cid completion:^(NSDictionary * _Nullable result, NSError * _Nullable error) {
        if (completion) completion(error);
    }];
}

- (void)disableDriverUID:(NSString *)driverUID
               companyID:(NSString *)companyID
              completion:(void(^)(NSError *))completion {
    NSString *cid = companyID.length > 0 ? companyID : [self effectiveCompanyID];
    [[PPDeliveryCompanyService shared] disableMemberUID:driverUID companyID:cid completion:^(NSDictionary * _Nullable result, NSError * _Nullable error) {
        if (completion) completion(error);
    }];
}

#pragma mark - Legacy Compatibility

- (void)fetchDeliveryRequestsWithCompletion:(void(^)(NSArray<PPDeliveryRequestRecord *> *, NSError *))completion {
    [self fetchCommandCenterWithCompletion:^(PPDeliveryCommandCenterSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        if (completion) completion(snapshot.records, error);
    }];
}

- (void)fetchAllDeliveryRequestsWithCompletion:(void(^)(NSArray<PPDeliveryRequestRecord *> *, NSError *))completion {
    [self fetchDeliveryRequestsWithCompletion:completion];
}

- (void)acceptRequest:(NSString *)requestID completion:(void(^)(NSError *))completion {
    PPDeliveryAllowedAction *action = [[PPDeliveryAllowedAction alloc] initWithDictionary:@{@"action": @"ACCEPT", @"expectedRevision": @0, @"expectedState": @"offered"}];
    [self executeAllowedAction:action requestID:requestID commandID:NSUUID.UUID.UUIDString driverUID:nil handoverConfirmed:NO reason:nil completion:^(__unused PPDeliveryCommandResult *res, NSError *err) {
        if (completion) completion(err);
    }];
}

- (void)assignDriver:(NSString *)requestID driverUID:(NSString *)driverUID completion:(void(^)(NSError *))completion {
    PPDeliveryAllowedAction *action = [[PPDeliveryAllowedAction alloc] initWithDictionary:@{@"action": @"ASSIGN", @"expectedRevision": @0, @"expectedState": @"accepted"}];
    [self executeAllowedAction:action requestID:requestID commandID:NSUUID.UUID.UUIDString driverUID:driverUID handoverConfirmed:NO reason:nil completion:^(__unused PPDeliveryCommandResult *res, NSError *err) {
        if (completion) completion(err);
    }];
}

- (void)completeRequest:(NSString *)requestID completion:(void(^)(NSError *))completion {
    PPDeliveryAllowedAction *action = [[PPDeliveryAllowedAction alloc] initWithDictionary:@{@"action": @"COMPLETE", @"expectedRevision": @0, @"expectedState": @"delivered"}];
    [self executeAllowedAction:action requestID:requestID commandID:NSUUID.UUID.UUIDString driverUID:nil handoverConfirmed:NO reason:nil completion:^(__unused PPDeliveryCommandResult *res, NSError *err) {
        if (completion) completion(err);
    }];
}

- (void)cancelRequest:(NSString *)requestID completion:(void(^)(NSError *))completion {
    PPDeliveryAllowedAction *action = [[PPDeliveryAllowedAction alloc] initWithDictionary:@{@"action": @"CANCEL", @"expectedRevision": @0, @"expectedState": @"pending"}];
    [self executeAllowedAction:action requestID:requestID commandID:NSUUID.UUID.UUIDString driverUID:nil handoverConfirmed:NO reason:nil completion:^(__unused PPDeliveryCommandResult *res, NSError *err) {
        if (completion) completion(err);
    }];
}

@end
