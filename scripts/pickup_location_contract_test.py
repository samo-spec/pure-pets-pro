#!/usr/bin/env python3
"""Source-contract checks for the Admin -> Infra -> Pro pickup boundary.

These checks do not compile or execute the native apps. Canonical coordinate,
branch-switch, authorization and replay behavior is exercised by Infra's
fulfillmentPickupStore suites separately.
"""

from pathlib import Path
import re
import unittest


WORKSPACE = Path(__file__).resolve().parents[2]
PRO = WORKSPACE / "Pure Pets Pro/PurePetsPro/DeliverySection"
ADMIN = WORKSPACE / "Pure Pets Admin/PurePetsAdmin/Features/Operations"
INFRA = WORKSPACE / "Pure Pets Infra/functions"


class PickupLocationContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.editor = (ADMIN / "PPBranchEditorView.swift").read_text()
        cls.model = (PRO / "PPDeliveryOrderModel.m").read_text()
        cls.manager = (PRO / "PPDeliveryManager.m").read_text()

    def test_admin_editor_uses_the_canonical_consumer_config(self):
        config = self.editor.split('document("ConsumerStockConfig")', 1)[1].split("let group", 1)[0]
        self.assertIn('"branchId": docID', config)
        for key in ("branchCode", "nameAr", "nameEn"):
            self.assertIn(f'"{key}":', config)
        self.assertNotIn("activeConsumerBranch", config)
        self.assertIn("config.branchId", (INFRA / "deliveryPickupStore.js").read_text())
        self.assertIn("merge: true", config)

    def test_admin_keeps_the_numeric_pair_separate_from_display_precision(self):
        self.assertIn('payload["latitude"] = lat', self.editor)
        self.assertIn('payload["longitude"] = lng', self.editor)
        self.assertIn('payload["locationPoints"]', self.editor)

    def test_selected_snapshot_supplies_address_and_point_as_one_candidate(self):
        loop = self.model.split('for (NSString *key in @[@"deliveryRequestPickupAddressSnapshot"', 1)[1]
        loop = loop.split("m.deliveryAreaName =", 1)[0]
        self.assertLess(loop.index('@"pickupAddress"'), loop.index('@"branchAddress"'))
        self.assertIn("NSString *point = PPOrderModelCoordinateQuery(address);", loop)
        self.assertIn("NSString *formatted = PPOrderModelExactAddressFromSnapshot(address);", loop)
        self.assertIn("pickupSnapshot = address;", loop)
        self.assertIn("m.pickupAddress = formatted;", loop)
        self.assertIn("m.pp_pickupCoordinateQuery = point;", loop)

    def test_inventory_branch_is_never_rewritten_by_pickup_projection(self):
        assignments = re.findall(r"\bm\.branchID\s*=([^;]+);", self.model)
        self.assertEqual(len(assignments), 1)
        self.assertIn('@[@"BranchID", @"branchId", @"branch_id"]', assignments[0])
        fallback = self.model.split("- (void)pp_applyPickupBranchFallback:", 1)[1].split("\n- (", 1)[0]
        self.assertNotRegex(fallback, r"self\.branchID\s*=")
        self.assertIn("if (self.pickupAddress.length || self.pp_pickupCoordinateQuery.length) return;", fallback)

    def test_operational_branch_and_name_precede_inventory_fallback(self):
        self.assertIn('@[@"deliveryRequestPickupBranchId", @"pickupBranchId"]', self.model)
        self.assertIn("![m.pickupBranchID isEqualToString:m.branchID]", self.model)
        self.assertIn("m.branchName = localizedPickupName;", self.model)
        self.assertIn("order.pickupBranchID ?: (order.branchID.length ? order.branchID : nil)", self.manager)
        summary = self.model.split("- (NSString *)pp_pickupLocationSummary", 1)[1].split("\n- (", 1)[0]
        self.assertLess(summary.index("self.pickupBranchID != nil"), summary.index("self.branchID.length"))

    def test_config_is_required_and_an_invalid_explicit_reference_cannot_fall_back(self):
        resolver = self.manager.split("- (void)refreshConsumerStockBranch", 1)[1].split("\n- (", 1)[0]
        self.assertIn("if (self.hasConsumerStockConfigSnapshot)", resolver)
        self.assertIn('self.consumerStockConfig[@"branchId"]', resolver)
        self.assertIn('![branchID containsString:@"/"]', resolver)
        self.assertIn("stock = self.branchPickupCache[branchID];", resolver)
        self.assertIn("} else {\n            stock = self.legacyConsumerStockBranch;", resolver)
        self.assertIn("PPDeliveryUsablePickupBranch(stock)", resolver)
        fallback = self.manager.split("- (void)applyPickupFallbackToOrder:", 1)[1].split("\n#pragma", 1)[0]
        self.assertIn("if (order.pp_pickupMapQuery.length) return;", fallback)
        self.assertIn("if (!PPDeliveryOrderIsPlatformFulfilled(order)) return;", fallback)
        self.assertIn("if (pickupBranchID != nil)", fallback)
        self.assertIn('pickupBranchID containsString:@"/"', fallback)
        self.assertLess(fallback.index("return;\n    }"), fallback.index("self.consumerStockBranch"))

    def test_provider_orders_cannot_borrow_a_platform_pickup(self):
        ownership = self.manager.split("static BOOL PPDeliveryOrderIsPlatformFulfilled", 1)[1].split("static NSString *PPDeliveryV1", 1)[0]
        self.assertIn("order.marketplaceOwnerType.lowercaseString", ownership)
        self.assertIn("order.marketplaceProviderID", ownership)
        self.assertIn("item.ownerType.lowercaseString", ownership)
        self.assertIn("item.ownerID", ownership)

    def test_assigned_children_override_the_parents_last_requested_sibling(self):
        self.assertIn("NSDictionary *child = childrenByID[fulfillmentID];", self.manager)
        self.assertIn("[order pp_applyAssignedPickupOrders:pickupOrders];", self.manager)
        method = self.model.split("- (void)pp_applyAssignedPickupOrders:", 1)[1].split("\n- (", 1)[0]
        self.assertIn("first.pp_pickupMapQuery isEqualToString:candidate.pp_pickupMapQuery", method)
        self.assertIn("self.pickupBranchID = unique ? branchID : @\"\";", method)
        self.assertIn("self.pp_pickupCoordinateQuery = unique ? first.pp_pickupCoordinateQuery : @\"\";", method)
        self.assertNotRegex(method, r"self\.branchID\s*=")

    def test_config_listener_is_bounded_account_bound_and_torn_down(self):
        listener = self.manager.split("- (void)startBranchesListener", 1)[1].split("- (void)refreshConsumerStockBranch", 1)[0]
        self.assertIn('documentWithPath:@"ConsumerStockConfig"', listener)
        self.assertEqual(listener.count("generation != strongSelf.branchListenerGeneration"), 2)
        self.assertEqual(listener.count("currentUser.uid isEqualToString:uid"), 2)
        stop = self.manager.split("- (void)stopListening {", 1)[1].split("- (void)stopOrderListeners", 1)[0]
        self.assertIn("self.branchListenerGeneration += 1;", stop)
        self.assertIn("[self.consumerStockConfigListener remove];", stop)
        self.assertIn("self.consumerStockConfigListener = nil;", stop)
        self.assertIn("self.branchPickupCache = @{};", stop)

    def test_map_actions_use_numeric_saved_point_and_preserve_full_precision(self):
        control = (PRO / "PPDeliveryDriverControlView.swift").read_text()
        self.assertIn("state.openAppleMapsNavigation(address: order.pp_pickupMapQuery())", control)
        self.assertNotIn("state.openAppleMapsNavigation(address: order.pp_pickupLocationSummary())", control)
        self.assertIn(".disabled(order.pp_pickupMapQuery().isEmpty)", control)
        self.assertIn("mapQuery: order.pp_pickupMapQuery()", (PRO / "PPInAppRouteModalView.swift").read_text())
        coordinate = self.model.split("PPOrderModelCoordinateQuery(NSDictionary *snapshot)", 1)[1].split("static NSString *", 1)[0]
        self.assertIn('@"%.17g,%.17g"', coordinate)
        self.assertIn('@[@"locationPoints"]', coordinate)
        self.assertIn("!isfinite(lat)", coordinate)
        self.assertIn("fabs(lat) > 90", coordinate)
        self.assertIn("fabs(lng) > 180", coordinate)


if __name__ == "__main__":
    unittest.main(verbosity=2)
