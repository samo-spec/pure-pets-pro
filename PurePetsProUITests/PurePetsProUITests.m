//
//  PurePetsProUITests.m
//  PurePetsProUITests
//
//  Created by Mohammed Ahmed on 20/08/2025.
//

#import <XCTest/XCTest.h>

@interface PurePetsProUITests : XCTestCase

@end

@implementation PurePetsProUITests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.

    // In UI tests it is usually best to stop immediately when a failure occurs.
    self.continueAfterFailure = NO;

    // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    // UI tests must launch the application that they test.
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch];

    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testLaunchPerformance {
    // This measures how long it takes to launch your application.
    [self measureWithMetrics:@[[[XCTApplicationLaunchMetric alloc] init]] block:^{
        [[[XCUIApplication alloc] init] launch];
    }];
}

- (XCUIApplication *)pp_launchPortalWithFixtures:(BOOL)fixtures language:(NSString *)language {
    XCUIApplication *app = [XCUIApplication new];
    NSMutableArray *args = [NSMutableArray arrayWithArray:@[@"-PPProIdentityPortalUITest", @"-AppLanguage", language]];
    if (fixtures) [args addObject:@"-PPProIdentityPortalFixtureAccounts"];
    app.launchArguments = args;
    [app launch];
    return app;
}

- (void)pp_attachPortalScreenshot:(XCUIApplication *)app name:(NSString *)name {
    XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:app.screenshot];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

- (void)testIdentityPortalFirstLoginAndCountrySelection {
    XCUIApplication *app = [self pp_launchPortalWithFixtures:NO language:@"en"];
    XCTAssertTrue([app.staticTexts[@"pro.login.screen"] waitForExistenceWithTimeout:15]);
    XCTAssertEqualObjects(app.staticTexts[@"pro.login.screen"].label, @"Your professional workspace");
    XCTAssertTrue(app.buttons[@"pro.login.apple"].exists);
    XCTAssertTrue(app.buttons[@"pro.login.google"].exists);
    XCTAssertTrue(app.buttons[@"pro.login.support"].exists);
    XCTAssertTrue(app.buttons[@"pro.login.language"].exists);
    XCTAssertEqual([app.buttons matchingIdentifier:@"pro.login.rememberedAccount"].count, 0u);
    XCUIElement *phone = app.textFields[@"pro.login.phone"];
    XCUIElement *next = app.buttons[@"pro.login.continue"];
    XCTAssertTrue(phone.exists);
    XCTAssertFalse(next.enabled);
    [phone tap];
    [phone typeText:@"12345678"];
    XCTAssertTrue(next.enabled);
    [app.buttons[@"pro.login.country"] tap];
    XCUIElement *search = app.textFields[@"pro.login.country.search"];
    XCTAssertTrue([search waitForExistenceWithTimeout:8]);
    [search tap];
    [search typeText:@"+20"];
    XCUIElement *egypt = app.buttons[@"pro.login.country.option.EG"];
    XCTAssertTrue([egypt waitForExistenceWithTimeout:8]);
    [egypt tap];
    XCTAssertTrue([app.buttons[@"pro.login.country"] waitForExistenceWithTimeout:8]);
    XCTAssertEqualObjects(app.buttons[@"pro.login.country"].value, @"+20");
    [self pp_attachPortalScreenshot:app name:@"Identity Portal English"];
}

- (void)testIdentityPortalRememberedAccountsArabic {
    XCUIApplication *app = [self pp_launchPortalWithFixtures:YES language:@"ar"];
    XCTAssertTrue([app.staticTexts[@"pro.login.screen"] waitForExistenceWithTimeout:15]);
    XCTAssertEqualObjects(app.staticTexts[@"pro.login.screen"].label, @"مساحتك المهنية");
    XCUIElementQuery *accounts = [app.buttons matchingIdentifier:@"pro.login.rememberedAccount"];
    XCTAssertEqual(accounts.count, 2u);
    XCUIElement *first = [accounts elementBoundByIndex:0];
    XCTAssertTrue(first.exists);
    [first tap];
    XCTAssertTrue(first.selected);
    XCUIElement *other = app.buttons[@"pro.login.anotherAccount"];
    if (!other.hittable) [app swipeUp];
    [other tap];
    XCTAssertFalse(first.selected);
    [self pp_attachPortalScreenshot:app name:@"Identity Portal Arabic remembered accounts"];
}

@end
