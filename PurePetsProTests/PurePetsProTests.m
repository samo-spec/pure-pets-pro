//
//  PurePetsProTests.m
//  PurePetsProTests
//
//  Created by Mohammed Ahmed on 20/08/2025.
//

#import <XCTest/XCTest.h>
#import "PPPaymentManagementModels.h"
#import "PPRolePermission.h"
#import "PPStaffAuth.h"
#import "PPProviderMarketplaceManager.h"

@interface PurePetsProTests : XCTestCase

@end

@implementation PurePetsProTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    PPPaymentAdminRecord *record = [PPPaymentAdminRecord recordFromDictionary:@{
        @"orderId": @"order_1",
        @"status": @"paid",
        @"refundStatus": @"",
        @"totalAmount": @100,
        @"currency": @"QAR"
    } documentID:@"order_1"];

    XCTAssertEqualObjects([record workflowStatusKey], @"paid");
}

- (void)testWorkflowStatusPrefersRefundSignals {
    PPPaymentAdminRecord *record = [PPPaymentAdminRecord recordFromDictionary:@{
        @"orderId": @"order_2",
        @"status": @"paid",
        @"totalAmount": @120,
        @"currency": @"QAR"
    } documentID:@"order_2"];

    PPPaymentAdminSupportRequest *refundRequest = [PPPaymentAdminSupportRequest requestFromDictionary:@{
        @"requestId": @"req_1",
        @"type": @"refund",
        @"status": @"refunded",
        @"finalResolution": @"refunded"
    } documentID:@"req_1"];

    [record applyRequestSummaries:@[refundRequest]];
    XCTAssertEqualObjects([record workflowStatusKey], @"refunded");
}

- (void)testCanApproveOnlyPendingOrders {
    XCTAssertTrue([PPPaymentAdminRecord canApproveOrderStatus:@"pending"]);
    XCTAssertTrue([PPPaymentAdminRecord canApproveOrderStatus:@"verification_pending"]);
    XCTAssertFalse([PPPaymentAdminRecord canApproveOrderStatus:@"paid"]);
    XCTAssertFalse([PPPaymentAdminRecord canApproveOrderStatus:@"cancelled"]);
}

- (void)testRefundResolutionRequiresRefundRequestType {
    PPPaymentAdminRecord *order = [PPPaymentAdminRecord recordFromDictionary:@{
        @"orderId": @"order_3",
        @"status": @"paid",
        @"transactionId": @"txn_1",
        @"paidAt": [NSDate date],
        @"totalAmount": @200
    } documentID:@"order_3"];

    PPPaymentAdminSupportRequest *complaintRequest = [PPPaymentAdminSupportRequest requestFromDictionary:@{
        @"requestId": @"req_2",
        @"type": @"complaint",
        @"status": @"approved"
    } documentID:@"req_2"];

    XCTAssertFalse([PPPaymentAdminRecord canResolveRequest:complaintRequest
                                                withAction:PPPaymentAdminRequestResolutionRefund
                                                    order:order]);
    XCTAssertFalse([PPPaymentAdminRecord canResolveRequest:complaintRequest
                                                withAction:PPPaymentAdminRequestResolutionPartialRefund
                                                    order:order]);
}

- (void)testCompleteResolutionAllowsReturnRequestsOnlyAfterApproval {
    PPPaymentAdminRecord *order = [PPPaymentAdminRecord recordFromDictionary:@{
        @"orderId": @"order_4",
        @"status": @"paid",
        @"transactionId": @"txn_4",
        @"paidAt": [NSDate date],
        @"totalAmount": @90
    } documentID:@"order_4"];

    PPPaymentAdminSupportRequest *returnPending = [PPPaymentAdminSupportRequest requestFromDictionary:@{
        @"requestId": @"req_3",
        @"type": @"return",
        @"status": @"pending_review"
    } documentID:@"req_3"];
    PPPaymentAdminSupportRequest *returnApproved = [PPPaymentAdminSupportRequest requestFromDictionary:@{
        @"requestId": @"req_4",
        @"type": @"return",
        @"status": @"approved"
    } documentID:@"req_4"];
    PPPaymentAdminSupportRequest *refundApproved = [PPPaymentAdminSupportRequest requestFromDictionary:@{
        @"requestId": @"req_5",
        @"type": @"refund",
        @"status": @"approved"
    } documentID:@"req_5"];

    XCTAssertFalse([PPPaymentAdminRecord canResolveRequest:returnPending
                                                withAction:PPPaymentAdminRequestResolutionComplete
                                                    order:order]);
    XCTAssertTrue([PPPaymentAdminRecord canResolveRequest:returnApproved
                                               withAction:PPPaymentAdminRequestResolutionComplete
                                                   order:order]);
    XCTAssertFalse([PPPaymentAdminRecord canResolveRequest:refundApproved
                                                withAction:PPPaymentAdminRequestResolutionComplete
                                                    order:order]);
}

- (void)testDefaultPermissionsDoNotElevateUnknownOrUserRoles {
    NSArray<NSString *> *elevatedPermissions = @[
        kPermPostAds,
        kPermProduction,
        kPermAdoption,
        kPermSellUsed
    ];

    for (NSString *permission in elevatedPermissions) {
        XCTAssertFalse([[PPRolePermission defaultPermissionsForRole:UserRoleUnknown] containsObject:permission],
                       @"Unknown must not receive %@", permission);
        XCTAssertFalse([[PPRolePermission defaultPermissionsForRole:UserRoleUser] containsObject:permission],
                       @"User must not receive %@ by default", permission);
    }
}

- (void)testLegacyStaffRoleMappingKeepsAdminSuperAdminAndPaymentsScoped {
    PPStaffRole adminRole = [PPStaffAuth staffRoleFromLegacyRole:5];
    PPStaffRole superAdminRole = [PPStaffAuth staffRoleFromLegacyRole:8];
    NSInteger paymentsLegacyRole = [PPStaffAuth legacyRoleFromStaffRole:PPStaffRolePaymentsManager];

    XCTAssertEqualObjects(adminRole, PPStaffRoleOwner);
    XCTAssertEqualObjects(superAdminRole, PPStaffRoleSuperAdmin);
    XCTAssertNotEqualObjects(adminRole, superAdminRole);
    XCTAssertNotEqual(paymentsLegacyRole, UserRoleAdmin);
    XCTAssertNotEqual(paymentsLegacyRole, UserRoleSuperAdmin);
    XCTAssertEqual(PPParseRoleFromUserDoc(@{ @"roleName": @"payments_manager" }), UserRoleUser);
}

- (void)testMarketplaceBranchFromDictionaryParsesAllFields {
    NSDictionary *dict = @{
        @"id": @"branch_77",
        @"code": @"HUB-01",
        @"name": @{
            @"ar": @"فرع لوسيل",
            @"en": @"Lusail Branch"
        },
        @"address": @"Marina Promenade, Lusail",
        @"phone": @"+974 4411 2233",
        @"isActive": @YES,
        @"isDefault": @YES
    };

    PPMarketplaceBranch *branch = [PPMarketplaceBranch branchFromDictionary:dict];
    XCTAssertNotNil(branch);
    XCTAssertEqualObjects(branch.branchID, @"branch_77");
    XCTAssertEqualObjects(branch.code, @"HUB-01");
    XCTAssertEqualObjects(branch.nameAr, @"فرع لوسيل");
    XCTAssertEqualObjects(branch.nameEn, @"Lusail Branch");
    XCTAssertEqualObjects(branch.address, @"Marina Promenade, Lusail");
    XCTAssertEqualObjects(branch.phone, @"+974 4411 2233");
    XCTAssertTrue(branch.active);
    XCTAssertTrue(branch.defaultBranch);

    NSDictionary *payload = [branch pickupAddressPayload];
    XCTAssertEqualObjects(payload[@"branchId"], @"branch_77");
    XCTAssertEqualObjects(payload[@"branchCode"], @"HUB-01");
    XCTAssertEqualObjects(payload[@"address"], @"Marina Promenade, Lusail");
    XCTAssertEqualObjects(payload[@"phone"], @"+974 4411 2233");
}

- (void)testMarketplaceBranchDisplayNameFallback {
    NSDictionary *dict = @{
        @"id": @"branch_88",
        @"code": @"HUB-88",
        @"name": @{},
        @"address": @"Al Sadd"
    };
    PPMarketplaceBranch *branch = [PPMarketplaceBranch branchFromDictionary:dict];
    XCTAssertEqualObjects([branch displayName], @"HUB-88");
}

- (void)testMarketplaceBranchWithDistrictAddressAndPhoneValidation {
    NSDictionary *dict = @{
        @"id": @"hub_qatar_99",
        @"code": @"HUB-LUS-99",
        @"name": @{
            @"ar": @"فرع لوسيل مارينا",
            @"en": @"Lusail Marina Hub"
        },
        @"address": @"Marina Promenade, Tower 14 - Lusail",
        @"phone": @"+974 5512 3456",
        @"isActive": @YES,
        @"isDefault": @YES
    };
    PPMarketplaceBranch *branch = [PPMarketplaceBranch branchFromDictionary:dict];
    XCTAssertNotNil(branch);
    XCTAssertEqualObjects(branch.nameAr, @"فرع لوسيل مارينا");
    XCTAssertEqualObjects(branch.nameEn, @"Lusail Marina Hub");
    XCTAssertTrue([branch.address containsString:@"Lusail"]);
    XCTAssertTrue([branch.phone containsString:@"5512 3456"]);

    NSDictionary *payload = [branch pickupAddressPayload];
    XCTAssertEqualObjects(payload[@"branchId"], @"hub_qatar_99");
    XCTAssertEqualObjects(payload[@"address"], @"Marina Promenade, Tower 14 - Lusail");
}

@end
