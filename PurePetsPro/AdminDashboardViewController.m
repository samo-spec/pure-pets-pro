//
//  AdminDashboardViewController.m
//  PurePetsAdmin
//

#ifndef PPLOG
#define PPLOG(fmt, ...) NSLog((@"[AdminHeader] " fmt), ##__VA_ARGS__)
#endif



#import "AdminDashboardViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "PPFirebaseCompat.h"
#import "NotificationsListViewController.h"
#import "NotificationSettingsViewController.h"
#import "NotificationManager.h"
#import "NotificationModel.h"
#import "PPDeliveryDashboardViewController.h"
#import "PPDeliveryCompanyService.h"
#import "PPDeliveryCompanySetupViewController.h"
#import "PPDeliveryCompanyDashboardViewController.h"
#import "PPDeliveryCompanyDetailViewController.h"
#import "PPDeliveryCompanyMembersViewController.h"
#import "PPDeliveryOrderModel.h"
#import "PPDeliveryManager.h"
#import "PPFulfillmentManager.h"
#import "PPFulfillmentModel.h"
#import "PPServicesListViewController.h"
#import "PPProviderApplicationManager.h"
#import "PPProviderSubscriptionManagmetVC.h"
#import "PPVetsListViewController.h"
#import "PPPharmacyMedicinesViewController.h"
#import "PPMarketplaceBranchesViewController.h"
#import <TOCropViewController/TOCropViewController.h>
#import "PPProProfileSettingsViewController.h"
#import "PPProviderProfileEditorViewController.h"
#import "PPProviderSupportChatsViewController.h"
#import "PPUserMessagesViewController.h"
#import "PPPaddingLabel.h"
#import "PPAdoptPetsListViewController.h"
#import "PurePetsPro-Swift.h"


static const NSUInteger PPAdminDashboardMaxQuickActionCount = 3;
static const NSInteger PPAdminChatMessageStatusRead = 3;
static NSString * const PPAdminQuickActionSignalDelivery = @"delivery";
static NSString * const PPAdminQuickActionSignalFulfillment = @"fulfillment";

static BOOL PPProDashboardUserHasPartnerApplicationInReview(UserModel *user) {
    if (![user isKindOfClass:UserModel.class]) {
        return NO;
    }
    NSString *status = [PPSafeString(user.partnerApplicationStatus).lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [status isEqualToString:@"pending"] ||
    [status isEqualToString:@"under_review"];
}

static NSString *PPAdminChatThreadIDFromMessage(FIRDocumentSnapshot *doc, NSDictionary *payload) {
    NSString *threadID = doc.reference.parent.parent.documentID ?: @"";
    if (threadID.length > 0) return threadID;
    threadID = PPSafeString(payload[@"threadID"]);
    if (threadID.length > 0) return threadID;
    threadID = PPSafeString(payload[@"threadId"]);
    if (threadID.length > 0) return threadID;
    threadID = PPSafeString(payload[@"chatID"]);
    if (threadID.length > 0) return threadID;
    return PPSafeString(payload[@"chatId"]);
}

@interface AdminDashboardViewController ()<TOCropViewControllerDelegate>
@property (nonatomic, strong) UIButton *addPhotoButton;
@property (nonatomic, strong) PPQuickActionsView *quickActionsView;

@property (nonatomic, strong) UIImageView *avatarIMV;
@property (nonatomic, strong) UILabel *welcomeLabel;
@property (nonatomic, strong) UILabel *adminNameLabel;
@property (nonatomic, strong) UILabel *dashboardSummaryLabel;
@property (nonatomic, strong) UILabel *dashboardAccessLabel;
@property (nonatomic, strong) UILabel *heroStatusPillLabel;
@property (nonatomic, strong) UIView *heroStatusDotView;
@property (nonatomic, strong) UILabel *heroCommandNumberLabel;
@property (nonatomic, strong) UILabel *heroFulfillmentMetricValueLabel;
@property (nonatomic, strong) UILabel *heroDeliveryMetricValueLabel;
@property (nonatomic, strong) UILabel *heroFulfillmentMetricTitleLabel;
@property (nonatomic, strong) UILabel *heroDeliveryMetricTitleLabel;
@property (nonatomic, strong) UIButton *heroPrimaryActionButton;
@property (nonatomic, strong) UIView *quickActionsRailContainer;
@property (nonatomic, strong) UIView *heroShadowView;
@property (nonatomic, strong) PPHero *heroSurfaceView;
 @property (nonatomic, strong) UIView *heroLiveLineView;
@property (nonatomic, strong) UIView *heroAvatarPulseView;
@property (nonatomic, strong) UIView *heroAvatarContainerView;
 @property (nonatomic, copy) NSArray<UIView *> *heroOrbitRingViews;

@property (nonatomic, strong) UIView *bgAmbientGlow1;
@property (nonatomic, strong) UIView *bgAmbientGlow2;
@property (nonatomic, strong) UIView *bgAmbientGlow3;
@property (nonatomic, strong) UIView *subscriptionFooterRoot;
@property (nonatomic, strong) UIView *subscriptionFooterCard;
@property (nonatomic, strong) PPPaddingLabel *subscriptionStatusPillLabel;
@property (nonatomic, strong) UILabel *subscriptionTitleLabel;
@property (nonatomic, strong) UILabel *subscriptionSubtitleLabel;
@property (nonatomic, strong) UILabel *subscriptionStatusValueLabel;
@property (nonatomic, strong) UILabel *subscriptionRenewalValueLabel;
@property (nonatomic, strong) UILabel *subscriptionPendingValueLabel;
@property (nonatomic, strong) UIImageView *subscriptionChevronView;

@property (nonatomic, strong) JGProgressHUD *hud;

@property (nonatomic, assign) BOOL headerSetupCompleted;
@property (nonatomic, assign) BOOL didForceLogoutForAccess;
@property (nonatomic, strong) id<FIRListenerRegistration> reg;
@property (nonatomic, strong) id<FIRListenerRegistration> quickActionFulfillmentSignalListener;
@property (nonatomic, strong) id<FIRListenerRegistration> quickActionDeliveryOpenSignalListener;
@property (nonatomic, strong) id<FIRListenerRegistration> quickActionDeliveryAssignedSignalListener;
@property (nonatomic, strong) id<FIRListenerRegistration> providerSubscriptionStateListener;
@property (nonatomic, strong) id<FIRListenerRegistration> pendingOrdersListener;
@property (nonatomic, strong) id<FIRListenerRegistration> inboxUnreadListener;
@property (nonatomic, assign) NSInteger inboxUnreadCount;
@property (nonatomic, strong) id<FIRListenerRegistration> supportChatsThreadsListener;
@property (nonatomic, strong) id<FIRListenerRegistration> supportChatsMessagesListener;
@property (nonatomic, strong) NSMutableSet<NSString *> *supportChatThreadIDs;
@property (nonatomic, strong) NSMutableSet<NSString *> *supportChatsUnreadThreadIDs;
@property (nonatomic, assign) NSInteger supportChatsUnreadThreadsCount;
@property (nonatomic, copy) NSString *quickActionSignalSignature;
@property (nonatomic, copy) NSSet<NSString *> *fulfillmentQuickActionSignals;
@property (nonatomic, copy) NSSet<NSString *> *deliveryOpenQuickActionSignals;
@property (nonatomic, copy) NSSet<NSString *> *deliveryAssignedQuickActionSignals;
@property (nonatomic, strong) NSArray<PPDeliveryOrderModel *> *pendingOrders;
@property (nonatomic, assign) NSInteger fulfillmentNewRequestsCount;
@property (nonatomic, strong) PPProviderOnboardingState *providerSubscriptionState;
@property (nonatomic, strong) NSError *providerSubscriptionError;
@property (nonatomic, assign) BOOL isProviderSubscriptionLoading;
@property (nonatomic, assign) BOOL hasUnseenFulfillmentQuickAction;
@property (nonatomic, assign) BOOL hasUnseenDeliveryQuickAction;
@property (nonatomic, assign) BOOL didPlayDashboardEntrance;
@property (nonatomic, assign) BOOL didStartHeaderAccentMotion;
@property (nonatomic, assign) BOOL didCompleteInitialDashboardLoad;
@property (nonatomic, strong, nullable) PPDeliveryCompanyProfile *deliveryCompanyContext;
@property (nonatomic, copy) NSArray<PPDeliveryCompanyRequest *> *deliveryCompanyDashboardRequests;
@property (nonatomic, copy, nullable) NSString *deliveryCompanyDashboardNextPageToken;
@property (nonatomic, strong, nullable) NSError *deliveryCompanyDashboardError;
@property (nonatomic, assign) BOOL isLoadingDeliveryCompanyDashboard;
- (nullable UserModel *)pp_activeDashboardUser;
- (BOOL)pp_canAccessPermission:(NSString *)permKey;
- (BOOL)pp_canManageDelivery;
- (BOOL)pp_canManageServices;
- (BOOL)pp_canManageVets;
- (BOOL)pp_canManagePharmacy;
- (BOOL)pp_canManageMarketplace;
- (BOOL)pp_canManageAdoption;
- (BOOL)pp_hasDeliveryCompanyWorkspaceForUser:(nullable UserModel *)user;
- (BOOL)pp_hasNonDeliveryCompanyWorkspaceForUser:(nullable UserModel *)user;
- (BOOL)pp_isDeliveryCompanyOnlyDashboardForUser:(nullable UserModel *)user;
- (NSArray<NSString *> *)pp_dashboardWorkspaceTitlesForUser:(nullable UserModel *)user includeDeliveryCompany:(BOOL)includeDeliveryCompany;
- (NSInteger)pp_dashboardWorkspaceCountForUser:(nullable UserModel *)user;
- (NSInteger)pp_dashboardHeroDeliveryCompanyActionCount;
- (NSInteger)pp_dashboardHeroFulfillmentActionCount;
- (NSInteger)pp_dashboardHeroDeliveryActionCount;
- (NSInteger)pp_pendingOrdersCount;
- (NSString *)pp_dashboardHeroActionSummaryWithFulfillmentCount:(NSInteger)fulfillmentCount
                                                  deliveryCount:(NSInteger)deliveryCount
                                           deliveryCompanyCount:(NSInteger)deliveryCompanyCount;
- (XLFormRowDescriptor *)adminRowWithTag:(NSString *)tag
                                    icon:(UIImage *)icon
                                   title:(NSString *)title
                                subtitle:(NSString *)subtitle
                                 vcClass:(Class)vcClass;
- (NSString *)pp_dashboardRoleBadgeTextForUser:(UserModel *)user;
- (NSString *)pp_dashboardSummaryTextForUser:(UserModel *)user;
- (void)pp_rebuildDashboardFormPreservingOffset:(BOOL)preserveOffset;
- (void)pp_refreshDeliveryCompanyMembership;
- (void)pp_applyDeliveryCompanyProfile:(nullable PPDeliveryCompanyProfile *)profile;
- (void)pp_refreshDeliveryCompanyDashboardSummary;
- (void)pp_openDeliveryCompanyDashboard;
- (void)pp_openDeliveryCompanyMembers;
- (void)pp_openProfileSettings;
- (void)pp_openProviderProfileEditor;
- (void)pp_openSupportChats;
- (nullable PPDeliveryCompanyRequest *)pp_activeDeliveryCompanyRequest;
- (NSInteger)pp_deliveryCompanyCountForStatuses:(NSArray<NSString *> *)statuses;
- (NSInteger)pp_completedDeliveryCompanyCountToday;
- (NSString *)pp_deliveryCompanyCountText:(NSInteger)count;
- (void)pp_updateDeliveryCompanyHeroState;
- (NSArray<NSString *> *)pp_formSectionSignature:(XLFormDescriptor *)form;
- (void)pp_restoreDashboardOffsetY:(CGFloat)previousOffsetY preserveOffset:(BOOL)preserveOffset;
- (void)pp_animateVisibleCellsModern;
- (void)pp_configureDashboardAppearance;
- (void)pp_buildDashboardHeaderIfNeeded;
- (void)pp_refreshQuickActions;
- (NSArray<PPQuickActionItem *> *)pp_dashboardQuickActions;
- (NSArray<PPDashboardQuickActionRailItem *> *)pp_dashboardQuickActionsRail;
- (NSArray<PPDashboardQuickActionRailItem *> *)pp_dashboardRailActions:(NSArray<PPDashboardQuickActionRailItem *> *)railActions
                                              excludingGridActions:(NSArray<PPQuickActionItem *> *)gridActions;
- (void)pp_startQuickActionSignalObserversForUser:(UserModel *)user;
- (void)pp_stopQuickActionSignalObservers;
- (void)pp_startPendingOrdersObserverForUID:(NSString *)uid;
- (void)pp_startFulfillmentQuickActionSignalObserverForUID:(NSString *)uid;
- (void)pp_startDeliveryQuickActionSignalObserversForUID:(NSString *)uid;
- (void)pp_startProviderSubscriptionObserver;
- (void)pp_stopProviderSubscriptionObserver;
- (void)pp_startInboxUnreadObserverForUser:(UserModel *)user;
- (void)pp_stopInboxUnreadObserver;
- (void)pp_updateNotificationsRowBadge;
- (void)pp_startSupportChatsUnreadObserverForUser:(UserModel *)user;
- (void)pp_stopSupportChatsUnreadObserver;
- (void)pp_recomputeSupportChatsUnreadCount;
- (void)pp_updateSupportChatsRowBadge;
- (void)pp_markQuickActionKindSeen:(NSString *)kind;
- (NSString *)pp_fulfillmentQuickActionSignalFingerprint:(PPFulfillmentModel *)model;
- (void)pp_applyFulfillmentQuickActionSignals:(NSSet<NSString *> *)signals;
- (void)pp_applyDeliveryOpenQuickActionSignals:(NSSet<NSString *> *)signals;
- (void)pp_applyDeliveryAssignedQuickActionSignals:(NSSet<NSString *> *)signals;
- (BOOL)pp_hasUnseenQuickActionSignals:(NSSet<NSString *> *)signals kind:(NSString *)kind;
- (NSSet<NSString *> *)pp_currentDeliveryQuickActionSignals;
- (NSSet<NSString *> *)pp_deliveryQuickActionSignalsFromDocuments:(NSArray<FIRDocumentSnapshot *> *)documents;
- (NSString *)pp_deliveryQuickActionSignalFingerprint:(PPDeliveryOrderModel *)order;
- (void)pp_updateDashboardHeroLiveState;
- (void)pp_handleDashboardHeroPrimaryAction;
- (NSString *)pp_accessSummaryForUser:(UserModel *)user;
- (XLFormRowDescriptor *)pp_rowDescriptorForIndexPath:(NSIndexPath *)indexPath;
- (NSString *)pp_formSectionTitleAtIndex:(NSInteger)section;
- (UIButton *)pp_dashboardHeaderButtonWithSymbol:(NSString *)symbol
                                        selector:(SEL)selector
                              accessibilityLabel:(NSString *)accessibilityLabel;
- (void)pp_playDashboardEntranceIfNeeded;
- (void)pp_startHeaderAccentMotionIfNeeded;
- (void)pp_stopHeaderAccentMotion;
- (void)pp_applyAvatarURL:(NSURL * _Nullable)url;
- (NSString *)pp_dashboardGreetingText;
- (void)pp_setupAmbientBackgroundGlows;
- (void)pp_updateAmbientGlowsForStyle;
- (void)pp_buildSubscriptionFooterIfNeeded;
- (void)pp_renderSubscriptionFooter;
- (void)pp_refreshSubscriptionFooterHeight;
- (void)pp_openSubscriptionManagement;
- (BOOL)pp_applyRoleUpdateToCurrentUser:(UserModel *)user;
- (void)pp_startDashboardAccessObserversForUser:(UserModel *)user;
- (UIColor *)pp_dashboardHeroSurfaceColor;
- (UIColor *)pp_dashboardHeroInsetSurfaceColor;
- (UIColor *)pp_dashboardHeroBorderColor;
- (UIColor *)pp_dashboardHeroLineColor;
- (UIColor *)pp_dashboardHeroPulseColor;
- (UIColor *)pp_dashboardHeroDotColor;
- (UIColor *)pp_dashboardHeroThreadColor;
- (UIColor *)pp_dashboardHeroSignalColor;
- (UIColor *)pp_dashboardHeroPlateColor;
- (UIColor *)pp_dashboardAvatarContainerColor;
- (UIColor *)pp_dashboardHeroShadowColor;
- (void)pp_applyDashboardHeroShadow;
- (UIView *)pp_dashboardHeroOrbitRingWithSize:(CGFloat)size accent:(BOOL)accent;
- (void)pp_refreshDashboardHeroMaterials;
@end

#pragma mark - Profile Settings



// PPProAppearanceSettingsViewController is now integrated into PPProProfileSettingsViewController

@implementation AdminDashboardViewController

// Called automatically by InjectionIII after it injects this class
- (void)injected {
    // e.g. rebuild layout / reload data
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    if ([self respondsToSelector:@selector(tableView)]) {
        [(UITableView *)[self valueForKey:@"tableView"] reloadData];
    }
}



- (instancetype)init {
    return [self initWithDeliveryCompanyProfile:nil];
}

- (instancetype)initWithDeliveryCompanyProfile:(PPDeliveryCompanyProfile *)profile {
    self = [super initWithForm:[XLFormDescriptor formDescriptor] style:UITableViewStyleInsetGrouped];
    if (self) {
        _deliveryCompanyDashboardRequests = @[];
        [self pp_applyDeliveryCompanyProfile:profile];
        self.form = [self buildLoginForm];
    }
    return self;
}

- (void)configureDeliveryCompanyProfile:(PPDeliveryCompanyProfile *)profile {
    [self pp_applyDeliveryCompanyProfile:profile];
    if (!self.isViewLoaded) {
        return;
    }
    [self pp_refreshDeliveryCompanyDashboardSummary];
    [self pp_rebuildDashboardFormPreservingOffset:YES];
    if (UsrMgr.currentUser) {
        [self updateHeaderWithUser:UsrMgr.currentUser];
    }
}

#pragma mark - Build Form
- (XLFormDescriptor *)buildLoginForm {

    if (!UsrMgr.currentUser) {
        NSString *uid = [FIRAuth auth].currentUser.uid;
        if (uid.length) {
            UsrMgr.currentUser = [UsrMgr p_readUserFromDisk:uid];
        }
    }

    DLog(@"UsrMgr AdminDashboardViewController UsrMgr.currentUser:%@", UsrMgr.currentUser);
    XLFormDescriptor *form = [XLFormDescriptor formDescriptor];

    CGFloat pointSize = 16;
    NSArray<UIColor *> *palette = @[AppPrimaryClr,
                                    [UIColor.darkGrayColor colorWithAlphaComponent:0.7]];
    NSArray<UIColor *> *palette2 = @[AppPrimaryClrDarker, AppPrimaryClrShiner];

    BOOL canManageDelivery = [self pp_canManageDelivery];
    BOOL canManageServices = [self pp_canManageServices];
    BOOL canManageMarketplace = [self pp_canManageMarketplace];
    BOOL canManageVets = [self pp_canManageVets];
    BOOL canManagePharmacy = [self pp_canManagePharmacy];
    BOOL canManageAdoption = [self pp_canManageAdoption];
    UserModel *dashboardUser = [self pp_activeDashboardUser];

    PPDeliveryCompanyProfile *deliveryCompanyProfile = self.deliveryCompanyContext;
    BOOL hasDeliveryCompanyAccess = [self pp_hasDeliveryCompanyWorkspaceForUser:dashboardUser];
    BOOL isAnyActiveProvider = hasDeliveryCompanyAccess || canManageServices || canManageMarketplace || canManageDelivery || canManageVets || canManagePharmacy || canManageAdoption;



    XLFormSectionDescriptor *notificationsSection = [XLFormSectionDescriptor formSectionWithTitle:kLang(@"NotificationsSupportChatsSection")];
    [form addFormSection:notificationsSection];

    XLFormRowDescriptor *notificationsRow = [self adminRowWithTag:@"notificationsInbox"
                                                             icon:[UIImage pp_symbolNamed:@"bell.badge.fill" pointSize:pointSize weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleDefault palette:palette makeTemplate:NO]
                                                            title:kLang(@"NotificationsTitle")
                                                         subtitle:kLang(@"NotificationsDashboardSubtitle")
                                                          vcClass:[NotificationsListViewController class]];
    if (self.inboxUnreadCount > 0) {
        NSMutableDictionary *notificationsValue = [notificationsRow.value mutableCopy] ?: [NSMutableDictionary dictionary];
        notificationsValue[@"badgeCount"] = @(self.inboxUnreadCount);
        notificationsRow.value = notificationsValue;
    }
    [notificationsSection addFormRow:notificationsRow];

    if (isAnyActiveProvider) {
        //  XLFormSectionDescriptor *supportSection = [XLFormSectionDescriptor formSectionWithTitle:kLang(@"ch_provider_support_dashboard_eyebrow")];
        //  [form addFormSection:supportSection];

        XLFormRowDescriptor *supportChatsRow = [self adminRowWithTag:@"providerSupportChats"
                                                                icon:[UIImage pp_symbolNamed:@"message.badge.fill" pointSize:pointSize weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleDefault palette:palette makeTemplate:NO]
                                                               title:kLang(@"ch_provider_support_chats_title")
                                                            subtitle:kLang(@"ch_provider_support_chats_subtitle")
                                                             vcClass:[PPProviderSupportChatsViewController class]];
        if (self.supportChatsUnreadThreadsCount > 0) {
            NSMutableDictionary *supportChatsValue = [supportChatsRow.value mutableCopy] ?: [NSMutableDictionary dictionary];
            supportChatsValue[@"badgeCount"] = @(self.supportChatsUnreadThreadsCount);
            supportChatsRow.value = supportChatsValue;
        }
        [notificationsSection addFormRow:supportChatsRow];
    }

if (PPAdminDashboardActivateDeliveryProviders && canManageDelivery) {
        XLFormSectionDescriptor *deliverySection = [XLFormSectionDescriptor formSectionWithTitle:kLang(@"DeliverySection")];
        [form addFormSection:deliverySection];

        XLFormRowDescriptor *deliveryRow = [self adminRowWithTag:@"delivery"
                                                             icon:[UIImage pp_symbolNamed:@"shippingbox.fill" pointSize:pointSize weight:UIImageSymbolWeightLight scale:UIImageSymbolScaleDefault palette:palette makeTemplate:NO]
                                                            title:kLang(@"DeliveryManagement")
                                                         subtitle:kLang(@"DeliveryManagementSubtitle")
                                                            vcClass:[PPDeliveryDashboardViewController class]];
        [deliverySection addFormRow:deliveryRow];
    }

    // Delivery Company section - available only to users with fleet-company access or a resolved membership.
    if (hasDeliveryCompanyAccess) {
        BOOL hasVerifiedDeliveryCompany = deliveryCompanyProfile.companyID.length > 0;
        XLFormSectionDescriptor *deliveryCompanySection =
            [XLFormSectionDescriptor formSectionWithTitle:kLang(@"DeliveryCompany_Section")];
        [form addFormSection:deliveryCompanySection];

        NSString *deliveryCompanySubtitle = hasVerifiedDeliveryCompany
            ? (deliveryCompanyProfile.isDriver
               ? kLang(@"DeliveryCompany_DashboardShell_MyAssignedSubtitle")
               : [NSString stringWithFormat:kLang(@"DeliveryCompany_DashboardEntry_Subtitle_Format"),
                                            deliveryCompanyProfile.name.length ? deliveryCompanyProfile.name : deliveryCompanyProfile.companyID,
                                            PPDeliveryCompanyRoleDisplayName(deliveryCompanyProfile.role)])
            : kLang(@"DeliveryCompany_SetupEntry_Subtitle");
        Class deliveryCompanyEntryClass = hasVerifiedDeliveryCompany
            ? PPDeliveryCompanyDashboardViewController.class
            : PPDeliveryCompanySetupViewController.class;
        XLFormRowDescriptor *deliveryCompanyRow =
            [self adminRowWithTag:@"deliveryCompany"
                             icon:[UIImage pp_symbolNamed:(hasVerifiedDeliveryCompany ? @"truck.box.fill" : @"building.2.crop.circle")
                                               pointSize:pointSize
                                                  weight:UIImageSymbolWeightSemibold
                                                   scale:UIImageSymbolScaleDefault
                                                 palette:palette
                                              makeTemplate:NO]
                             title:hasVerifiedDeliveryCompany
                                   ? (deliveryCompanyProfile.isDriver
                                      ? kLang(@"DeliveryCompany_DashboardShell_MyAssigned")
                                      : kLang(@"DeliveryCompany_Title"))
                                   : kLang(@"DeliveryCompany_SetupEntry_Title")
                          subtitle:deliveryCompanySubtitle
                           vcClass:deliveryCompanyEntryClass];
        [deliveryCompanySection addFormRow:deliveryCompanyRow];

        if (hasVerifiedDeliveryCompany && deliveryCompanyProfile.canViewMembers) {
            XLFormRowDescriptor *membersRow =
                [self adminRowWithTag:@"deliveryCompanyMembers"
                                 icon:[UIImage pp_symbolNamed:@"person.3.fill"
                                                   pointSize:pointSize
                                                      weight:UIImageSymbolWeightSemibold
                                                       scale:UIImageSymbolScaleDefault
                                                     palette:palette
                                                  makeTemplate:NO]
                                title:kLang(@"DeliveryCompany_Tab_Members")
                             subtitle:kLang(@"DeliveryCompany_Dashboard_MembersShortcutSubtitle")
                              vcClass:nil];
            __weak typeof(self) weakSelf = self;
            membersRow.action.formBlock = ^(__unused XLFormRowDescriptor *rowDescriptor) {
                [weakSelf pp_openDeliveryCompanyMembers];
            };
            [deliveryCompanySection addFormRow:membersRow];
        }
    }




    // Provider Support Chats section - for all active providers to see customer messages


    if (canManageServices || canManageMarketplace) {
        XLFormSectionDescriptor *serviceSection = [XLFormSectionDescriptor formSectionWithTitle:kLang(@"ManageServices")];
        [form addFormSection:serviceSection];

        if (canManageServices) {
            XLFormRowDescriptor *manageServicesRow = [self adminRowWithTag:@"manageServices"
                                                                      icon:[UIImage pp_symbolNamed:@"scissors" pointSize:pointSize weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleDefault palette:palette makeTemplate:NO]
                                                                     title:kLang(@"ManageServices")
                                                                  subtitle:kLang(@"ProviderTypeServiceSubtitle")
                                                                   vcClass:[PPServicesListViewController class]];
            [serviceSection addFormRow:manageServicesRow];
        }

        XLFormRowDescriptor *fulfillmentRow = [self adminRowWithTag:@"fulfillmentOrders"
                                                               icon:[UIImage pp_symbolNamed:@"shippingbox.fill" pointSize:pointSize weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleDefault palette:palette makeTemplate:NO]
                                                              title:kLang(@"Fulfillment_Title")
                                                           subtitle:kLang(@"Fulfillment_EmptySubtitle")
                                                            vcClass:[PPFulfillmentListViewController class]];
        [serviceSection addFormRow:fulfillmentRow];

        if (canManageMarketplace) {
            XLFormRowDescriptor *marketRow = [self adminRowWithTag:@"marketItems"
                                                              icon:[UIImage pp_symbolNamed:@"bag.fill" pointSize:pointSize weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleDefault palette:palette makeTemplate:NO]
                                                             title:kLang(@"Market_Title")
                                                          subtitle:kLang(@"Market_EmptySubtitle")
                                                           vcClass:[PPProviderMarketItemsViewController class]];
            [serviceSection addFormRow:marketRow];
        }
    }

    if (canManagePharmacy) {
        XLFormSectionDescriptor *pharmacySection = [XLFormSectionDescriptor formSectionWithTitle:kLang(@"Pharmacy_Section_Title")];
        [form addFormSection:pharmacySection];

        XLFormRowDescriptor *managePharmacyRow = [self adminRowWithTag:@"managePharmacy"
                                                                  icon:[UIImage pp_symbolNamed:@"pills.fill" pointSize:pointSize weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleDefault palette:palette makeTemplate:NO]
                                                                 title:kLang(@"Pharmacy_Manage_Title")
                                                              subtitle:kLang(@"Pharmacy_Manage_Subtitle")
                                                               vcClass:[PPPharmacyMedicinesViewController class]];
        [pharmacySection addFormRow:managePharmacyRow];
    }

    if (canManageAdoption) {
        XLFormSectionDescriptor *adoptPetsSection = [XLFormSectionDescriptor formSectionWithTitle:kLang(@"AdoptPetsSection")];
        [form addFormSection:adoptPetsSection];

        XLFormRowDescriptor *adoptPetsListRow = [self adminRowWithTag:@"adoptPetsList"
                                                                 icon:[UIImage pp_symbolNamed:@"heart.fill" pointSize:pointSize weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleDefault palette:palette makeTemplate:NO]
                                                                title:kLang(@"AdoptPetsTitle")
                                                             subtitle:kLang(@"AdoptPetsSubtitle")
                                                              vcClass:[PPAdoptPetsListViewController class]];
        [adoptPetsSection addFormRow:adoptPetsListRow];
    }

    if (isAnyActiveProvider) {
        XLFormSectionDescriptor *settingsSection = [XLFormSectionDescriptor formSectionWithTitle:kLang(@"Settings")];
        [form addFormSection:settingsSection];

        XLFormRowDescriptor *profileSettingsRow = [self adminRowWithTag:@"profileSettings"
                                                                   icon:[UIImage pp_symbolNamed:@"person.crop.circle.fill" pointSize:pointSize weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleDefault palette:palette makeTemplate:NO]
                                                                  title:kLang(@"ProfileSettings")
                                                               subtitle:kLang(@"ProfileSettingsSubtitle")
                                                                vcClass:[PPProProfileSettingsViewController class]];
        [settingsSection addFormRow:profileSettingsRow];

        XLFormRowDescriptor *notificationSettingsRow = [self adminRowWithTag:@"notificationSettings"
                                                                        icon:[UIImage pp_symbolNamed:@"bell.badge.fill" pointSize:pointSize weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleDefault palette:palette makeTemplate:NO]
                                                                       title:kLang(@"NotificationSettings")
                                                                    subtitle:kLang(@"NotificationSettingsSubtitle")
                                                                     vcClass:[NotificationSettingsViewController class]];
        [settingsSection addFormRow:notificationSettingsRow];

        XLFormRowDescriptor *branchesManagementRow = [self adminRowWithTag:@"branchesManagement"
                                                                      icon:[UIImage pp_symbolNamed:@"building.2.crop.circle" pointSize:pointSize weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleDefault palette:palette makeTemplate:NO]
                                                                     title:kLang(@"MarketplaceBranches_Manage")
                                                                  subtitle:kLang(@"MarketplaceBranches_ProfileRowSubtitle")
                                                                   vcClass:[PPMarketplaceBranchesViewController class]];
        [settingsSection addFormRow:branchesManagementRow];
    }

    return form;
}

- (void)pp_applyDeliveryCompanyProfile:(PPDeliveryCompanyProfile *)profile {
    self.deliveryCompanyContext = profile;
    self.deliveryCompanyId = profile.companyID ?: @"";
    NSString *name = profile.name.length ? profile.name : (profile.legalName.length ? profile.legalName : profile.companyID);
    self.deliveryCompanyName = name ?: @"";
    self.memberRole = profile.role ?: @"";
    self.isDeliveryCompanyMode = profile.companyID.length > 0 && profile.role.length > 0;
    if (!self.isDeliveryCompanyMode) {
        self.deliveryCompanyDashboardRequests = @[];
        self.deliveryCompanyDashboardNextPageToken = nil;
        self.deliveryCompanyDashboardError = nil;
    }
}

- (nullable UserModel *)pp_activeDashboardUser {
    if (UsrMgr.currentUser) return UsrMgr.currentUser;
    NSString *uid = [FIRAuth auth].currentUser.uid;
    if (!uid.length) return nil;
    return [UsrMgr p_readUserFromDisk:uid];
}

- (BOOL)pp_applyRoleUpdateToCurrentUser:(UserModel *)user {
    if (!user) return NO;
    UserModel *current = UsrMgr.currentUser;
    if (!current) {
        UsrMgr.currentUser = user;
        return YES;
    }

    BOOL changed = current.role != user.role ||
    current.isAdmin != user.isAdmin ||
    current.isSuperAdmin != user.isSuperAdmin ||
    current.isBlocked != user.isBlocked ||
    current.canOfferServices != user.canOfferServices ||
    current.canDelivery != user.canDelivery ||
    current.canOfferServicesFeature != user.canOfferServicesFeature ||
    current.canDeliveryFeature != user.canDeliveryFeature ||
    current.canDeliveryCompanyFeature != user.canDeliveryCompanyFeature ||
    current.canVetFeature != user.canVetFeature ||
    current.canPharmacyFeature != user.canPharmacyFeature ||
    current.canAccessProviderMarketplaceFeature != user.canAccessProviderMarketplaceFeature ||
    current.partnerOnboardingVisible != user.partnerOnboardingVisible ||
    ![PPSafeString(current.partnerApplicationStatus) isEqualToString:PPSafeString(user.partnerApplicationStatus)] ||
    ![PPSafeString(current.selectedPartnerType) isEqualToString:PPSafeString(user.selectedPartnerType)] ||
    current.canAccessPartnerAppPermission != user.canAccessPartnerAppPermission ||
    current.canManageDeliveryPermission != user.canManageDeliveryPermission ||
    current.canManageServiceProviderPermission != user.canManageServiceProviderPermission ||
    current.canManageVetPermission != user.canManageVetPermission ||
    current.canPostVetProfilePermission != user.canPostVetProfilePermission ||
    current.canEditVetInfoPermission != user.canEditVetInfoPermission ||
    current.canManagePetMedicinesPermission != user.canManagePetMedicinesPermission;

    if (!changed) return NO;

    current.role = user.role;
    current.isAdmin = user.isAdmin;
    current.isSuperAdmin = user.isSuperAdmin;
    current.isBlocked = user.isBlocked;
    current.canOfferServices = user.canOfferServices;
    current.canDelivery = user.canDelivery;
    current.canOfferServicesFeature = user.canOfferServicesFeature;
    current.canDeliveryFeature = user.canDeliveryFeature;
    current.canDeliveryCompanyFeature = user.canDeliveryCompanyFeature;
    current.canVetFeature = user.canVetFeature;
    current.canPharmacyFeature = user.canPharmacyFeature;
    current.canAccessProviderMarketplaceFeature = user.canAccessProviderMarketplaceFeature;
    current.partnerOnboardingVisible = user.partnerOnboardingVisible;
    current.partnerApplicationStatus = user.partnerApplicationStatus ?: @"";
    current.selectedPartnerType = user.selectedPartnerType ?: @"";
    current.canAccessPartnerAppPermission = user.canAccessPartnerAppPermission;
    current.canManageDeliveryPermission = user.canManageDeliveryPermission;
    current.canManageServiceProviderPermission = user.canManageServiceProviderPermission;
    current.canManageVetPermission = user.canManageVetPermission;
    current.canPostVetProfilePermission = user.canPostVetProfilePermission;
    current.canEditVetInfoPermission = user.canEditVetInfoPermission;
    current.canManagePetMedicinesPermission = user.canManagePetMedicinesPermission;
    return YES;
}

- (BOOL)pp_canAccessPermission:(NSString *)permKey {
    if (permKey.length == 0) return NO;

    UserModel *user = [self pp_activeDashboardUser];
    if (!user) return NO;

    return [user hasPermissionNamed:permKey];
}

- (UIColor *)pp_settingsurfaceColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.17 green:0.17 blue:0.19 alpha:0.92];
        }
        return [[UIColor whiteColor] colorWithAlphaComponent:0.82];
    }];
}

- (BOOL)pp_canManageServices {
    UserModel *user = [self pp_activeDashboardUser];
    if (!user) return NO;

    return (user.canOfferServices || user.canOfferServicesFeature) && user.canManageServiceProviderPermission;
}

- (BOOL)pp_canManageDelivery {
    if (!PPProviderTypeIsEnabledInProApp(PPProviderTypeDeliverySubscription)) {
        return NO;
    }
    UserModel *user = [self pp_activeDashboardUser];
    if (!user) return NO;

    return (user.canDelivery || user.canDeliveryFeature) && user.canManageDeliveryPermission;
}

- (BOOL)pp_canManageVets {
    UserModel *user = [self pp_activeDashboardUser];
    if (!user) return NO;

    return user.canVetFeature && user.canManageVetPermission;
}

- (BOOL)pp_canManagePharmacy {
    UserModel *user = [self pp_activeDashboardUser];
    if (!user) return NO;
    return user.canPharmacyFeature && user.canManagePetMedicinesPermission;
}

- (BOOL)pp_canManageAdoption {
    UserModel *user = [self pp_activeDashboardUser];
    if (!user) return NO;
    return user.canAdoption;
}

- (BOOL)pp_canManageMarketplace {
    UserModel *user = [self pp_activeDashboardUser];
    if (!user) return NO;
    return user.canAccessProviderMarketplaceFeature;
}

- (BOOL)pp_hasDeliveryCompanyWorkspaceForUser:(UserModel *)user {
    return self.isDeliveryCompanyMode || user.canDeliveryCompanyFeature;
}

- (BOOL)pp_hasNonDeliveryCompanyWorkspaceForUser:(UserModel *)user {
    if (!user) {
        return NO;
    }
    return [self pp_canManageServices] ||
           [self pp_canManageMarketplace] ||
           [self pp_canManageDelivery] ||
           [self pp_canManageVets] ||
           [self pp_canManagePharmacy] ||
           [self pp_canManageAdoption];
}

- (BOOL)pp_isDeliveryCompanyOnlyDashboardForUser:(UserModel *)user {
    return [self pp_hasDeliveryCompanyWorkspaceForUser:user] &&
           ![self pp_hasNonDeliveryCompanyWorkspaceForUser:user];
}

- (NSArray<NSString *> *)pp_dashboardWorkspaceTitlesForUser:(UserModel *)user includeDeliveryCompany:(BOOL)includeDeliveryCompany {
    NSMutableArray<NSString *> *workspaceTitles = [NSMutableArray array];
    if (!user) {
        return workspaceTitles.copy;
    }

    if ([self pp_canManageMarketplace]) {
        [workspaceTitles addObject:kLang(@"Market_Title")];
    }
    if ([self pp_canManagePharmacy]) {
        [workspaceTitles addObject:kLang(@"Pharmacy_Section_Title")];
    }
    if ([self pp_canManageServices]) {
        [workspaceTitles addObject:kLang(@"ManageServices")];
    }
    if ([self pp_canManageVets]) {
        [workspaceTitles addObject:kLang(@"ProviderTypeVetTitle")];
    }
    if (includeDeliveryCompany && [self pp_hasDeliveryCompanyWorkspaceForUser:user]) {
        NSString *fleetTitle = (self.isDeliveryCompanyMode && self.deliveryCompanyContext.isDriver)
            ? kLang(@"DeliveryCompany_DashboardShell_MyAssigned")
            : kLang(@"DeliveryCompany_Title");
        [workspaceTitles addObject:fleetTitle];
    }
    if ([self pp_canManageDelivery]) {
        [workspaceTitles addObject:kLang(@"DeliverySection")];
    }
    if ([self pp_canManageAdoption]) {
        [workspaceTitles addObject:kLang(@"AdoptPetsTitle")];
    }
    return workspaceTitles.copy;
}

- (NSInteger)pp_dashboardWorkspaceCountForUser:(UserModel *)user {
    return (NSInteger)[self pp_dashboardWorkspaceTitlesForUser:user includeDeliveryCompany:YES].count;
}

- (NSInteger)pp_dashboardHeroDeliveryCompanyActionCount {
    if (!self.isDeliveryCompanyMode || !self.deliveryCompanyContext.companyID.length) {
        return 0;
    }
    PPDeliveryCompanyProfile *profile = self.deliveryCompanyContext;
    if (profile.isDriver) {
        NSInteger assignedCount = [self pp_deliveryCompanyCountForStatuses:@[PPDeliveryCompanyStatusAssigned]];
        NSInteger inTransitCount = [self pp_deliveryCompanyCountForStatuses:@[
            PPDeliveryCompanyStatusPickedUp,
            PPDeliveryCompanyStatusInTransit
        ]];
        return assignedCount + inTransitCount;
    }
    if (profile.isViewer) {
        return 0;
    }
    return [self pp_deliveryCompanyCountForStatuses:@[PPDeliveryCompanyStatusOffered]];
}

- (NSString *)pp_dashboardHeroActionSummaryWithFulfillmentCount:(NSInteger)fulfillmentCount
                                                  deliveryCount:(NSInteger)deliveryCount
                                           deliveryCompanyCount:(NSInteger)deliveryCompanyCount {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (fulfillmentCount > 0) {
        [parts addObject:[NSString stringWithFormat:kLang(@"DashboardHero_ActionPart_Fulfillment_Format"), (long)fulfillmentCount]];
    }
    if (deliveryCount > 0) {
        [parts addObject:[NSString stringWithFormat:kLang(@"DashboardHero_ActionPart_Delivery_Format"), (long)deliveryCount]];
    }
    if (deliveryCompanyCount > 0) {
        [parts addObject:[NSString stringWithFormat:kLang(@"DashboardHero_ActionPart_Fleet_Format"), (long)deliveryCompanyCount]];
    }
    return [parts componentsJoinedByString:@" • "];
}

- (NSString *)pp_dashboardRoleBadgeTextForUser:(UserModel *)user {
    if ([self pp_isDeliveryCompanyOnlyDashboardForUser:user] && self.isDeliveryCompanyMode) {
        return PPDeliveryCompanyRoleDisplayName(self.memberRole);
    }
    if (!user) {
        return kLang(@"pp_role_admin");
    }

    NSArray<NSString *> *workspaceTitles = [self pp_dashboardWorkspaceTitlesForUser:user includeDeliveryCompany:YES];
    if (workspaceTitles.count > 0) {
        return [workspaceTitles componentsJoinedByString:@" & "];
    }

    NSString *localizedRole = [PPRolePermission localizedRoleName:user.role];
    return localizedRole.length ? localizedRole : kLang(@"pp_role_admin");
}

- (NSString *)pp_dashboardSummaryTextForUser:(UserModel *)user {
    if ([self pp_isDeliveryCompanyOnlyDashboardForUser:user] && self.isDeliveryCompanyMode) {
        return self.deliveryCompanyContext.isDriver
            ? kLang(@"DeliveryCompany_DashboardShell_DriverSummary")
            : kLang(@"DeliveryCompany_DashboardShell_CompanySummary");
    }
    if (!user) {
        return @"";
    }

    NSMutableArray<NSString *> *workspaceSummaries = [NSMutableArray array];
    if ([self pp_canManageMarketplace]) {
        [workspaceSummaries addObject:kLang(@"Market_EmptySubtitle")];
    }
    if ([self pp_canManagePharmacy]) {
        [workspaceSummaries addObject:kLang(@"Pharmacy_Manage_Subtitle")];
    }
    if ([self pp_canManageServices]) {
        [workspaceSummaries addObject:kLang(@"ProviderTypeServiceSubtitle")];
    }
    if ([self pp_canManageVets]) {
        [workspaceSummaries addObject:kLang(@"Vet_Manage_Subtitle")];
    }
    if ([self pp_hasDeliveryCompanyWorkspaceForUser:user]) {
        NSString *fleetSummary = self.deliveryCompanyContext.isDriver
            ? kLang(@"DeliveryCompany_DashboardShell_DriverSummary")
            : kLang(@"DeliveryCompany_DashboardShell_CompanySummary");
        [workspaceSummaries addObject:fleetSummary];
    }
    if ([self pp_canManageDelivery]) {
        [workspaceSummaries addObject:kLang(@"DeliveryManagementSubtitle")];
    }
    if ([self pp_canManageAdoption]) {
        [workspaceSummaries addObject:kLang(@"AdoptPetsSubtitle")];
    }

    NSString *workspaceSummary = [workspaceSummaries componentsJoinedByString:@" • "];
    if (workspaceSummary.length > 0) {
        return workspaceSummary;
    }

    return [PPRolePermission localizedRoleDescription:user.role] ?: @"";
}

- (NSString *)pp_dashboardGreetingText {
    NSDateComponents *components = [[NSCalendar currentCalendar] components:NSCalendarUnitHour fromDate:[NSDate date]];
    NSInteger hour = components.hour;
    if (hour >= 5 && hour < 12) {
        return kLang(@"Dashboard_Greeting_Morning");
    }
    if (hour >= 12 && hour < 17) {
        return kLang(@"Dashboard_Greeting_Afternoon");
    }
    return kLang(@"Dashboard_Greeting_Evening");
}

- (void)pp_applyDashboardNameForUser:(UserModel *)user {
    NSString *resolvedName = user.displayName.length ? user.displayName : [user PPBestDisplayName];
    if (resolvedName.length == 0) {
        resolvedName = kLang(@"pp_me_guest");
    }

    NSString *greeting = [self pp_dashboardGreetingText];
    NSString *format = kLang(@"Dashboard_Greeting_Name_Format");
    self.welcomeLabel.text = [NSString stringWithFormat:format, greeting, resolvedName];
    [self pp_updateDashboardHeroLiveState];
}

- (void)pp_requestDebouncedDashboardRebuild {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pp_executeRebuildDashboardForm) object:nil];
    [self performSelector:@selector(pp_executeRebuildDashboardForm) withObject:nil afterDelay:0.15];
}

- (void)pp_refreshDeliveryCompanyMembership {
    if (PPDeliveryCompanyService.shared.isRefreshingProfile) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    [PPDeliveryCompanyService.shared refreshConfiguredProfileWithCompletion:^(PPDeliveryCompanyProfile * _Nullable profile,
                                                                               NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.isViewLoaded) return;
        if (profile.companyID.length > 0) {
            [strongSelf pp_applyDeliveryCompanyProfile:profile];
            [strongSelf pp_refreshDeliveryCompanyDashboardSummary];
        } else if (error) {
            NSLog(@"[DeliveryCompanyDashboard] Membership refresh failed: %@", error.localizedDescription);
        }
        [strongSelf pp_requestDebouncedDashboardRebuild];
    }];
}

- (void)pp_refreshDeliveryCompanyDashboardSummary {
    PPDeliveryCompanyProfile *profile = self.deliveryCompanyContext;
    if (!self.isDeliveryCompanyMode || !profile.companyID.length || self.isLoadingDeliveryCompanyDashboard) {
        return;
    }

    self.isLoadingDeliveryCompanyDashboard = YES;
    self.deliveryCompanyDashboardError = nil;
    [self pp_updateDashboardHeroLiveState];
    __weak typeof(self) weakSelf = self;
    [PPDeliveryCompanyService.shared listRequestsForProfile:profile
                                             nextPageToken:nil
                                                completion:^(NSArray<PPDeliveryCompanyRequest *> * _Nullable requests,
                                                             NSString * _Nullable nextPageToken,
                                                             NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || ![self.deliveryCompanyId isEqualToString:profile.companyID]) {
                return;
            }
            self.isLoadingDeliveryCompanyDashboard = NO;
            self.deliveryCompanyDashboardError = error;
            if (!error) {
                self.deliveryCompanyDashboardRequests = requests ?: @[];
                self.deliveryCompanyDashboardNextPageToken = nextPageToken;
            }
            [self pp_updateDashboardHeroLiveState];
            [self pp_refreshQuickActions];
        });
    }];
}

- (void)pp_openDeliveryCompanyDashboard {
    if (!self.isDeliveryCompanyMode) {
        return;
    }
    [PPFunc pp_playTapEffect];
    PPDeliveryCompanyDashboardViewController *controller = [[PPDeliveryCompanyDashboardViewController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)pp_openDeliveryCompanyMembers {
    if (!self.deliveryCompanyContext.canViewMembers) {
        return;
    }
    [PPFunc pp_playTapEffect];
    PPDeliveryCompanyMembersViewController *controller =
        [[PPDeliveryCompanyMembersViewController alloc] initWithProfile:self.deliveryCompanyContext];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)pp_openProfileSettings {
    [PPFunc pp_playTapEffect];
    PPProProfileSettingsViewController *controller = [[PPProProfileSettingsViewController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)pp_openProviderProfileEditor {
    [PPFunc pp_playTapEffect];
    PPProviderProfileEditorViewController *controller = [[PPProviderProfileEditorViewController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)pp_openSupportChats {
    [PPFunc pp_playTapEffect];
    PPProviderSupportChatsViewController *controller = [[PPProviderSupportChatsViewController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

- (PPDeliveryCompanyRequest *)pp_activeDeliveryCompanyRequest {
    for (PPDeliveryCompanyRequest *request in self.deliveryCompanyDashboardRequests) {
        if ([request.status isEqualToString:PPDeliveryCompanyStatusAssigned] ||
            [request.status isEqualToString:PPDeliveryCompanyStatusPickedUp] ||
            [request.status isEqualToString:PPDeliveryCompanyStatusInTransit]) {
            return request;
        }
    }
    return nil;
}

- (NSInteger)pp_deliveryCompanyCountForStatuses:(NSArray<NSString *> *)statuses {
    NSSet<NSString *> *statusSet = [NSSet setWithArray:statuses ?: @[]];
    NSInteger count = 0;
    for (PPDeliveryCompanyRequest *request in self.deliveryCompanyDashboardRequests) {
        if ([statusSet containsObject:request.status ?: @""]) {
            count += 1;
        }
    }
    return count;
}

- (NSInteger)pp_completedDeliveryCompanyCountToday {
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSInteger count = 0;
    for (PPDeliveryCompanyRequest *request in self.deliveryCompanyDashboardRequests) {
        if ([request.status isEqualToString:PPDeliveryCompanyStatusCompleted] &&
            request.updatedAt &&
            [calendar isDateInToday:request.updatedAt]) {
            count += 1;
        }
    }
    return count;
}

- (NSString *)pp_deliveryCompanyCountText:(NSInteger)count {
    if (self.isLoadingDeliveryCompanyDashboard ||
        (self.deliveryCompanyDashboardError && self.deliveryCompanyDashboardRequests.count == 0)) {
        return @"--";
    }
    return self.deliveryCompanyDashboardNextPageToken.length > 0
        ? [NSString stringWithFormat:@"%ld+", (long)count]
        : [NSString stringWithFormat:@"%ld", (long)count];
}

- (void)pp_executeRebuildDashboardForm {
    [self pp_rebuildDashboardFormPreservingOffset:YES];
}

- (void)pp_rebuildDashboardFormPreservingOffset:(BOOL)preserveOffset {
    CGFloat previousOffsetY = self.tableView.contentOffset.y;
    NSArray<NSString *> *oldSignature = [self pp_formSectionSignature:self.form];
    XLFormDescriptor *updatedForm = [self buildLoginForm];
    NSArray<NSString *> *newSignature = [self pp_formSectionSignature:updatedForm];
    BOOL didChangeSections = ![oldSignature isEqualToArray:newSignature];

    if (!didChangeSections && self.form) {
        if (UsrMgr.currentUser) {
            [self pp_refreshQuickActions];
            [self updateHeaderWithUser:UsrMgr.currentUser];
        }
        [self pp_restoreDashboardOffsetY:previousOffsetY preserveOffset:preserveOffset];
        return;
    }

    self.form = updatedForm;
    if (UsrMgr.currentUser) {
        [self pp_refreshQuickActions];
        [self updateHeaderWithUser:UsrMgr.currentUser];
    }

    BOOL shouldAnimate = didChangeSections && self.isViewLoaded && self.view.window != nil;
    if (shouldAnimate) {
        [UIView transitionWithView:self.tableView
                          duration:0.30
                           options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent
                        animations:^{
            [self.tableView reloadData];
            [self.tableView layoutIfNeeded];
        } completion:^(__unused BOOL finished) {
            [self pp_restoreDashboardOffsetY:previousOffsetY preserveOffset:preserveOffset];
            [self pp_animateVisibleCellsModern];
        }];
        return;
    }

    [self.tableView reloadData];
    [self pp_restoreDashboardOffsetY:previousOffsetY preserveOffset:preserveOffset];
}

- (void)pp_startDashboardAccessObserversForUser:(UserModel *)user {
    if (!user.uid.length) {
        return;
    }

    if (self.reg) {
        [self.reg remove];
        self.reg = nil;
    }

    __weak typeof(self) weakSelf = self;
    self.reg = [RPM listenPermissionsForUID:user.uid onChange:^(NSDictionary<NSString *,NSNumber *> * _Nonnull perms, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || error) return;

        NSLog(@"👂 Live perms for %@: %@", user.uid, perms);

        NSDictionary *incomingPermissions = perms ?: @{};
        NSDictionary *existingPermissions = UsrMgr.currentUser.permissions ?: @{};
        BOOL hadExistingPermissions = UsrMgr.currentUser.permissions.count > 0;
        if (incomingPermissions.count > 0 || hadExistingPermissions) {
            if (![existingPermissions isEqualToDictionary:incomingPermissions]) {
                if (!UsrMgr.currentUser.permissions) {
                    UsrMgr.currentUser.permissions = [NSMutableDictionary dictionary];
                }
                [UsrMgr.currentUser.permissions setDictionary:incomingPermissions];
                [strongSelf pp_requestDebouncedDashboardRebuild];
                [strongSelf setupHeaderUIWithUser:UsrMgr.currentUser];
            }
        }
    }];

    [RPM listenForRoleChangesOfUser:user.uid completion:^(UserModel * _Nullable incomingUser, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (error) {
            NSLog(@"❌ Role listener error: %@", error);
            return;
        }
        if (!incomingUser) {
            NSLog(@"⚠️ Role listener returned no user model yet; keeping current dashboard session");
            return;
        }

BOOL canAccessAdmin = PPIsAllowedAdminRole(incomingUser.role) || incomingUser.isAdmin || incomingUser.isSuperAdmin;
        BOOL canAccessDeliveryPro = PPAdminDashboardActivateDeliveryProviders && (incomingUser.canDelivery || incomingUser.canDeliveryFeature);
        BOOL canAccessDeliveryCompanyPro = incomingUser.canDeliveryCompanyFeature;
        BOOL canAccessPro = canAccessAdmin ||
        canAccessDeliveryPro ||
        canAccessDeliveryCompanyPro ||
        incomingUser.canOfferServices ||
        incomingUser.canVetFeature ||
        incomingUser.canAccessProviderMarketplaceFeature ||
        incomingUser.canPharmacyFeature;
        BOOL blocked = incomingUser.isBlocked;
        BOOL hasReviewApplication = PPProDashboardUserHasPartnerApplicationInReview(incomingUser);

        NSLog(@"👂 Role update: role=%@ admin=%d pro=%d blocked=%d review=%d",
              [PPRolePermission roleName:incomingUser.role], incomingUser.isAdmin, canAccessPro, blocked, hasReviewApplication);

        if ((blocked || !canAccessPro || hasReviewApplication) && !strongSelf.didForceLogoutForAccess) {
            strongSelf.didForceLogoutForAccess = YES;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (blocked) {
                    [PPAlertHelper showErrorIn:strongSelf
                                         title:kLang(@"Error")
                                      subtitle:kLang(@"StatusAccountBlocked")];
                    [[UserManager shared] signOut];
                    return;
                }

                PPProviderSubscriptionManagmetVC *statusController = [[PPProviderSubscriptionManagmetVC alloc] init];
                statusController.prefersAutoPresentBecomeProvider = NO;

                [strongSelf.navigationController setViewControllers:@[statusController] animated:YES];
            });
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL roleChanged = [strongSelf pp_applyRoleUpdateToCurrentUser:incomingUser];
            if (!roleChanged) {
                return;
            }
            [strongSelf updateHeaderWithUser:UsrMgr.currentUser];
            [strongSelf pp_requestDebouncedDashboardRebuild];
        });
    }];
}

- (NSArray<NSString *> *)pp_formSectionSignature:(XLFormDescriptor *)form {
    if (!form) return @[];

    NSMutableArray<NSString *> *signature = [NSMutableArray array];
    for (XLFormSectionDescriptor *section in form.formSections) {
        NSString *title = section.title ?: @"";
        NSMutableArray<NSString *> *rowTags = [NSMutableArray array];
        for (XLFormRowDescriptor *row in section.formRows) {
            if (row.tag.length > 0) {
                [rowTags addObject:row.tag];
            }
        }
        NSString *rowsToken = rowTags.count > 0
        ? [rowTags componentsJoinedByString:@","]
        : [NSString stringWithFormat:@"rows:%lu", (unsigned long)section.formRows.count];
        [signature addObject:[NSString stringWithFormat:@"%@|%@", title, rowsToken]];
    }
    return signature.copy;
}

- (void)pp_restoreDashboardOffsetY:(CGFloat)previousOffsetY preserveOffset:(BOOL)preserveOffset {
    [self.tableView layoutIfNeeded];
    CGFloat minOffsetY = -self.tableView.adjustedContentInset.top;
    CGFloat maxOffsetY = MAX(minOffsetY,
                             self.tableView.contentSize.height - self.tableView.bounds.size.height + self.tableView.adjustedContentInset.bottom);
    if (!preserveOffset) {
        [self.tableView setContentOffset:CGPointMake(0, minOffsetY) animated:NO];
        return;
    }

    BOOL wasAtTop = previousOffsetY <= (minOffsetY + 1.0);
    CGFloat clamped = wasAtTop ? minOffsetY : MIN(MAX(previousOffsetY, minOffsetY), maxOffsetY);
    [self.tableView setContentOffset:CGPointMake(0, clamped) animated:NO];
}

- (void)pp_animateVisibleCellsModern {
    NSArray<UITableViewCell *> *cells = self.tableView.visibleCells;
    [cells enumerateObjectsUsingBlock:^(UITableViewCell *cell, NSUInteger idx, __unused BOOL *stop) {
        cell.alpha = 0.0;
        cell.transform = CGAffineTransformMakeTranslation(0, 16);
        [UIView animateWithDuration:0.55
                              delay:0.04 * idx
             usingSpringWithDamping:0.82
              initialSpringVelocity:0.35
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            cell.alpha = 1.0;
            cell.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (XLFormRowDescriptor *)adminRowWithTag:(NSString *)tag
                                    icon:(UIImage *)icon
                                   title:(NSString *)title
                                subtitle:(NSString *)subtitle
                                 vcClass:(Class)vcClass {

    XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:tag
                                                                     rowType:@"XLAdminCell"];
    row.value = @{
        @"icon": icon ?: [UIImage new],
        @"title": title ?: @"",
        @"subtitle": subtitle ?: @""
    };


    // Use formBlock for navigation
    __weak typeof(self) weakSelf = self;
    row.action.formBlock = ^(XLFormRowDescriptor *rowDescriptor) {
        if (vcClass) {
            [PPFunc pp_playTapEffect];
            NSLog(@"rowDescriptor");
            UIViewController *vc = [[vcClass alloc] init];
            [weakSelf.navigationController pushViewController:vc animated:YES];
        }
    };

    return row;
}

- (void)pp_configureDashboardAppearance {
    UIColor *surfaceColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;

    self.view.backgroundColor = AppBackgroundClrDarker ?: UIColor.systemGroupedBackgroundColor;
    self.tableView.hidden = NO;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.clipsToBounds = NO;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.layoutMargins = UIEdgeInsetsMake(1 ,6, 1, 6);
    self.tableView.separatorInset = UIEdgeInsetsMake(1, 6, 1, 6);
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.showsHorizontalScrollIndicator = NO;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.contentInset = UIEdgeInsetsMake(10, 0, 32, 0);
    self.tableView.tableFooterView = [UIView new];
    self.tableView.estimatedRowHeight = 16.0;
    self.tableView.estimatedSectionHeaderHeight = 46.0;
    self.tableView.sectionHeaderHeight = UITableViewAutomaticDimension;

    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 4.0;
    }

    self.tableView.refreshControl.tintColor = AppPrimaryClr ?: surfaceColor;

    [self pp_setupAmbientBackgroundGlows];
    [self pp_buildSubscriptionFooterIfNeeded];
}

#pragma mark - Subscription Footer

- (UIColor *)pp_subscriptionFooterSurfaceColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.10 green:0.10 blue:0.11 alpha:0.96];
        }
        return [UIColor colorWithWhite:1.0 alpha:0.88];
    }];
}

- (UIColor *)pp_subscriptionFooterInsetColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:1.0 alpha:0.055];
        }
        return [UIColor colorWithWhite:0.0 alpha:0.030];
    }];
}

- (void)pp_buildSubscriptionFooterIfNeeded {
    if (self.subscriptionFooterRoot) {
        [self pp_refreshSubscriptionFooterHeight];
        return;
    }

    self.isProviderSubscriptionLoading = YES;

    UIColor *accent = AppPrimaryClr ?: UIColor.systemTealColor;
    UIColor *secondaryText = SeconderyTextClr ?: UIColor.secondaryLabelColor;

    UIView *root = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 1.0)];
    root.backgroundColor = UIColor.clearColor;
    root.clipsToBounds = NO;
    root.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.subscriptionFooterRoot = root;

    UIView *shadowWrap = [[UIView alloc] init];
    shadowWrap.translatesAutoresizingMaskIntoConstraints = NO;
    shadowWrap.backgroundColor = UIColor.clearColor;
    shadowWrap.layer.shadowColor = (AppShadowColor ?: UIColor.blackColor).CGColor;
    shadowWrap.layer.shadowOpacity = 0.08;
    shadowWrap.layer.shadowRadius = 18.0;
    shadowWrap.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    [root addSubview:shadowWrap];

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [self pp_subscriptionFooterSurfaceColor];
    card.layer.cornerRadius = 28.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.clipsToBounds = YES;
    card.isAccessibilityElement = YES;
    card.accessibilityTraits = UIAccessibilityTraitButton;
    [shadowWrap addSubview:card];
    self.subscriptionFooterCard = card;

    UIView *inset = [[UIView alloc] init];
    inset.translatesAutoresizingMaskIntoConstraints = NO;
    inset.backgroundColor = [self pp_subscriptionFooterInsetColor];
    inset.layer.cornerRadius = 24.0;
    inset.layer.cornerCurve = kCACornerCurveContinuous;
    inset.userInteractionEnabled = NO;
    [card addSubview:inset];

    UIView *iconSurface = [[UIView alloc] init];
    iconSurface.translatesAutoresizingMaskIntoConstraints = NO;
    iconSurface.backgroundColor = [accent colorWithAlphaComponent:0.10];
    iconSurface.layer.cornerRadius = 24.0;
    iconSurface.layer.cornerCurve = kCACornerCurveContinuous;
    [card addSubview:iconSurface];

    UIImageSymbolConfiguration *iconConfig = [UIImageSymbolConfiguration configurationWithPointSize:18.0 weight:UIImageSymbolWeightSemibold];
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"creditcard.and.123" withConfiguration:iconConfig]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = accent;
    [iconSurface addSubview:iconView];

    self.subscriptionStatusPillLabel = [[PPPaddingLabel alloc] init];
    self.subscriptionStatusPillLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subscriptionStatusPillLabel.font = [Styling fontBold:11.0];
    self.subscriptionStatusPillLabel.textInsets = UIEdgeInsetsMake(7.0, 12.0, 7.0, 12.0);
    self.subscriptionStatusPillLabel.textColor = accent;
    self.subscriptionStatusPillLabel.backgroundColor = [accent colorWithAlphaComponent:0.10];
    self.subscriptionStatusPillLabel.layer.cornerRadius = 14.0;
    self.subscriptionStatusPillLabel.layer.cornerCurve = kCACornerCurveContinuous;
    self.subscriptionStatusPillLabel.clipsToBounds = YES;
    [card addSubview:self.subscriptionStatusPillLabel];

    UILabel *eyebrow = [[UILabel alloc] init];
    eyebrow.translatesAutoresizingMaskIntoConstraints = NO;
    eyebrow.font = [Styling fontBold:11.0];
    eyebrow.textColor = [accent colorWithAlphaComponent:0.92];
    eyebrow.textAlignment = Language.alignmentForCurrentLanguage;
    eyebrow.text = kLang(@"ProviderSubscriptionCardEyebrow");
    [card addSubview:eyebrow];

    self.subscriptionTitleLabel = [[UILabel alloc] init];
    self.subscriptionTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subscriptionTitleLabel.font = [Styling fontBold:22.0];
    self.subscriptionTitleLabel.textColor = PrimaryTextClr ?: UIColor.labelColor;
    self.subscriptionTitleLabel.numberOfLines = 2;
    self.subscriptionTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:self.subscriptionTitleLabel];

    self.subscriptionSubtitleLabel = [[UILabel alloc] init];
    self.subscriptionSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subscriptionSubtitleLabel.font = [Styling fontRegular:13.0];
    self.subscriptionSubtitleLabel.textColor = [secondaryText colorWithAlphaComponent:0.92];
    self.subscriptionSubtitleLabel.numberOfLines = 0;
    self.subscriptionSubtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [card addSubview:self.subscriptionSubtitleLabel];

    UIStackView *metricsStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self pp_subscriptionMetricWithCaption:kLang(@"ProviderSubscriptionCardStatusCaption") valueLabel:&_subscriptionStatusValueLabel],
        [self pp_subscriptionMetricWithCaption:kLang(@"ProviderSubscriptionCardRenewCaption") valueLabel:&_subscriptionRenewalValueLabel],
        [self pp_subscriptionMetricWithCaption:kLang(@"ProviderSubscriptionCardPendingCaption") valueLabel:&_subscriptionPendingValueLabel],
    ]];
    metricsStack.translatesAutoresizingMaskIntoConstraints = NO;
    metricsStack.axis = UILayoutConstraintAxisHorizontal;
    metricsStack.alignment = UIStackViewAlignmentFill;
    metricsStack.distribution = UIStackViewDistributionFillEqually;
    metricsStack.spacing = 8.0;
    metricsStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [card addSubview:metricsStack];

    self.subscriptionChevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:Language.isRTL ? @"chevron.left" : @"chevron.right"]];
    self.subscriptionChevronView.translatesAutoresizingMaskIntoConstraints = NO;
    self.subscriptionChevronView.tintColor = secondaryText;
    self.subscriptionChevronView.contentMode = UIViewContentModeScaleAspectFit;
    [card addSubview:self.subscriptionChevronView];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_openSubscriptionManagement)];
    [card addGestureRecognizer:tap];

    [NSLayoutConstraint activateConstraints:@[
        [shadowWrap.topAnchor constraintEqualToAnchor:root.topAnchor constant:12.0],
        [shadowWrap.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:PPAdminDashboardHorizontalInset],
        [shadowWrap.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-PPAdminDashboardHorizontalInset],
        [shadowWrap.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-28.0],

        [card.topAnchor constraintEqualToAnchor:shadowWrap.topAnchor],
        [card.leadingAnchor constraintEqualToAnchor:shadowWrap.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:shadowWrap.trailingAnchor],
        [card.bottomAnchor constraintEqualToAnchor:shadowWrap.bottomAnchor],

        [inset.topAnchor constraintEqualToAnchor:card.topAnchor constant:1.0],
        [inset.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:1.0],
        [inset.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-1.0],
        [inset.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-1.0],

        [iconSurface.topAnchor constraintEqualToAnchor:card.topAnchor constant:20.0],
        [iconSurface.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20.0],
        [iconSurface.widthAnchor constraintEqualToConstant:48.0],
        [iconSurface.heightAnchor constraintEqualToConstant:48.0],
        [iconView.centerXAnchor constraintEqualToAnchor:iconSurface.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconSurface.centerYAnchor],

        [self.subscriptionStatusPillLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:20.0],
        [self.subscriptionStatusPillLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20.0],

        [eyebrow.topAnchor constraintEqualToAnchor:card.topAnchor constant:22.0],
        [eyebrow.leadingAnchor constraintEqualToAnchor:iconSurface.trailingAnchor constant:14.0],
        [eyebrow.trailingAnchor constraintLessThanOrEqualToAnchor:self.subscriptionStatusPillLabel.leadingAnchor constant:-12.0],

        [self.subscriptionTitleLabel.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:8.0],
        [self.subscriptionTitleLabel.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [self.subscriptionTitleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20.0],

        [self.subscriptionSubtitleLabel.topAnchor constraintEqualToAnchor:self.subscriptionTitleLabel.bottomAnchor constant:8.0],
        [self.subscriptionSubtitleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20.0],
        [self.subscriptionSubtitleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20.0],

        [metricsStack.topAnchor constraintEqualToAnchor:self.subscriptionSubtitleLabel.bottomAnchor constant:16.0],
        [metricsStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14.0],
        [metricsStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-48.0],
        [metricsStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18.0],

        [self.subscriptionChevronView.centerYAnchor constraintEqualToAnchor:metricsStack.centerYAnchor],
        [self.subscriptionChevronView.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20.0],
        [self.subscriptionChevronView.widthAnchor constraintEqualToConstant:13.0],
        [self.subscriptionChevronView.heightAnchor constraintEqualToConstant:20.0],
    ]];

    self.tableView.tableFooterView = root;
    [self pp_renderSubscriptionFooter];
    [self pp_refreshSubscriptionFooterHeight];
}

- (UIView *)pp_subscriptionMetricWithCaption:(NSString *)caption valueLabel:(UILabel * __strong *)valueLabel {
    UIView *surface = [[UIView alloc] init];
    surface.translatesAutoresizingMaskIntoConstraints = NO;
    surface.backgroundColor = [self pp_subscriptionFooterInsetColor];
    surface.layer.cornerRadius = 16.0;
    surface.layer.cornerCurve = kCACornerCurveContinuous;

    UILabel *captionLabel = [[UILabel alloc] init];
    captionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    captionLabel.font = [Styling fontMedium:10.0];
    captionLabel.textColor = (SeconderyTextClr ?: UIColor.secondaryLabelColor);
    captionLabel.textAlignment = Language.alignmentForCurrentLanguage;
    captionLabel.text = caption;
    [surface addSubview:captionLabel];

    UILabel *metricValueLabel = [[UILabel alloc] init];
    metricValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    metricValueLabel.font = [Styling fontBold:13.0];
    metricValueLabel.textColor = PrimaryTextClr ?: UIColor.labelColor;
    metricValueLabel.numberOfLines = 2;
    metricValueLabel.adjustsFontSizeToFitWidth = YES;
    metricValueLabel.minimumScaleFactor = 0.78;
    metricValueLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [surface addSubview:metricValueLabel];
    if (valueLabel) {
        *valueLabel = metricValueLabel;
    }

    [NSLayoutConstraint activateConstraints:@[
        [captionLabel.topAnchor constraintEqualToAnchor:surface.topAnchor constant:12.0],
        [captionLabel.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:12.0],
        [captionLabel.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-12.0],
        [metricValueLabel.topAnchor constraintEqualToAnchor:captionLabel.bottomAnchor constant:5.0],
        [metricValueLabel.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:12.0],
        [metricValueLabel.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-12.0],
        [metricValueLabel.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-12.0],
        [surface.heightAnchor constraintGreaterThanOrEqualToConstant:72.0],
    ]];
    return surface;
}

- (void)pp_startProviderSubscriptionObserver {
    [self pp_stopProviderSubscriptionObserver];
    self.isProviderSubscriptionLoading = YES;
    self.providerSubscriptionError = nil;
    [self pp_renderSubscriptionFooter];

    __weak typeof(self) weakSelf = self;
    self.providerSubscriptionStateListener = [[PPProviderApplicationManager shared] observeProviderStateForCurrentUser:^(PPProviderOnboardingState * _Nullable state, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.isProviderSubscriptionLoading = NO;
        strongSelf.providerSubscriptionState = state;
        strongSelf.providerSubscriptionError = error;
        [strongSelf pp_renderSubscriptionFooter];
    }];
}

- (void)pp_stopProviderSubscriptionObserver {
    [self.providerSubscriptionStateListener remove];
    self.providerSubscriptionStateListener = nil;
}

- (void)pp_startInboxUnreadObserverForUser:(UserModel *)user {
    [self pp_stopInboxUnreadObserver];
    if (!user.uid.length) return;

    __weak typeof(self) weakSelf = self;
    self.inboxUnreadListener = [[NotificationManager shared] observeInboxForUser:user.uid handler:^(NSArray<NotificationModel *> *items) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        NSInteger unreadCount = 0;
        for (NotificationModel *item in items) {
            if (![item isKindOfClass:NotificationModel.class]) continue;
            if (!item.isRead) unreadCount += 1;
        }
        strongSelf.inboxUnreadCount = unreadCount;
        [strongSelf pp_updateNotificationsRowBadge];
    }];
}

- (void)pp_stopInboxUnreadObserver {
    [self.inboxUnreadListener remove];
    self.inboxUnreadListener = nil;
}

- (void)pp_updateNotificationsRowBadge {
    XLFormRowDescriptor *notificationsRow = [self.form formRowWithTag:@"notificationsInbox"];
    if (!notificationsRow) return;

    NSMutableDictionary *dict = [notificationsRow.value mutableCopy] ?: [NSMutableDictionary dictionary];
    if (self.inboxUnreadCount > 0) {
        dict[@"badgeCount"] = @(self.inboxUnreadCount);
    } else {
        [dict removeObjectForKey:@"badgeCount"];
    }
    notificationsRow.value = dict;
    [self reloadFormRow:notificationsRow];
}

- (void)pp_startSupportChatsUnreadObserverForUser:(UserModel *)user {
    [self pp_stopSupportChatsUnreadObserver];
    NSString *providerUID = user.uid.length > 0 ? user.uid : ([FIRAuth auth].currentUser.uid ?: @"");
    if (providerUID.length == 0) return;

    self.supportChatThreadIDs = [NSMutableSet set];
    self.supportChatsUnreadThreadIDs = [NSMutableSet set];
    self.supportChatsUnreadThreadsCount = 0;
    [self pp_updateSupportChatsRowBadge];

    FIRQuery *threadsQuery =
    [[[[[[FIRFirestore firestore] collectionWithPath:@"Chats"]
        queryWhereField:@"members" arrayContains:providerUID]
       queryWhereField:@"conversationType" isEqualTo:@"provider_chat"]
      queryWhereField:@"supportUserId" isEqualTo:providerUID]
     queryOrderedByField:@"timestamp" descending:YES];

    __weak typeof(self) weakSelf = self;
    self.supportChatsThreadsListener = [threadsQuery addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !snapshot) {
                NSLog(@"[DashboardSupportBadge] Thread listener failed: %@", error.localizedDescription ?: @"unknown error");
                return;
            }
            NSMutableSet<NSString *> *threadIDs = [NSMutableSet set];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                if (doc.exists && doc.documentID.length > 0) [threadIDs addObject:doc.documentID];
            }
            strongSelf.supportChatThreadIDs = threadIDs;
            [strongSelf pp_recomputeSupportChatsUnreadCount];
        });
    }];

    FIRQuery *messagesQuery =
    [[[[FIRFirestore firestore] collectionGroupWithID:@"Messages"]
      queryWhereField:@"receiverID" isEqualTo:providerUID]
     queryWhereField:@"status" isLessThan:@(PPAdminChatMessageStatusRead)];

    self.supportChatsMessagesListener = [messagesQuery addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !snapshot) {
                NSLog(@"[DashboardSupportBadge] Unread-message listener failed: %@", error.localizedDescription ?: @"unknown error");
                return;
            }
            NSMutableSet<NSString *> *unreadThreadIDs = [NSMutableSet set];
            for (FIRDocumentSnapshot *doc in snapshot.documents) {
                if (!doc.exists) continue;
                NSString *threadID = PPAdminChatThreadIDFromMessage(doc, doc.data ?: @{});
                if (threadID.length > 0) [unreadThreadIDs addObject:threadID];
            }
            strongSelf.supportChatsUnreadThreadIDs = unreadThreadIDs;
            [strongSelf pp_recomputeSupportChatsUnreadCount];
        });
    }];
}

- (void)pp_recomputeSupportChatsUnreadCount {
    NSMutableSet<NSString *> *intersection = [NSMutableSet setWithSet:self.supportChatsUnreadThreadIDs ?: [NSSet set]];
    [intersection intersectSet:self.supportChatThreadIDs ?: [NSSet set]];
    NSInteger nextCount = (NSInteger)intersection.count;
    if (nextCount == self.supportChatsUnreadThreadsCount) return;
    self.supportChatsUnreadThreadsCount = nextCount;
    [self pp_updateSupportChatsRowBadge];
}

- (void)pp_stopSupportChatsUnreadObserver {
    [self.supportChatsThreadsListener remove];
    self.supportChatsThreadsListener = nil;
    [self.supportChatsMessagesListener remove];
    self.supportChatsMessagesListener = nil;
    self.supportChatThreadIDs = nil;
    self.supportChatsUnreadThreadIDs = nil;
}

- (void)pp_updateSupportChatsRowBadge {
    XLFormRowDescriptor *supportChatsRow = [self.form formRowWithTag:@"providerSupportChats"];
    if (supportChatsRow) {
        NSMutableDictionary *dict = [supportChatsRow.value mutableCopy] ?: [NSMutableDictionary dictionary];
        if (self.supportChatsUnreadThreadsCount > 0) {
            dict[@"badgeCount"] = @(self.supportChatsUnreadThreadsCount);
        } else {
            [dict removeObjectForKey:@"badgeCount"];
        }
        supportChatsRow.value = dict;
        [self reloadFormRow:supportChatsRow];
    }
    [self pp_refreshQuickActions];
}

- (NSArray<NSNumber *> *)pp_providerTypeDisplayOrder {
    NSMutableArray<NSNumber *> *types = [NSMutableArray array];
    for (NSNumber *typeNumber in @[@(PPProviderTypeMarketplace), @(PPProviderTypeDeliveryCompany), @(PPProviderTypeVet), @(PPProviderTypePharmacy), @(PPProviderTypeDeliverySubscription), @(PPProviderTypeService)]) {
        if (PPProviderTypeIsEnabledInProApp(typeNumber.integerValue)) {
            [types addObject:typeNumber];
        }
    }
    return types.copy;
}

- (PPProviderProfile *)pp_primaryActiveProviderProfileForState:(PPProviderOnboardingState *)state {
    for (NSNumber *typeNumber in [self pp_providerTypeDisplayOrder]) {
        PPProviderType type = typeNumber.integerValue;
        PPProviderProfile *profile = [state profileForType:type];
        NSString *status = [PPSafeString(profile.status).lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([state isActiveForType:type] || [status isEqualToString:@"active"]) {
            return profile ?: [[PPProviderProfile alloc] init];
        }
    }
    return nil;
}

- (NSUInteger)pp_pendingProviderApplicationCountForState:(PPProviderOnboardingState *)state {
    NSUInteger count = 0;
    for (PPProviderApplication *application in state.applications ?: @[]) {
        NSString *status = [PPSafeString(application.status).lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([status isEqualToString:@"pending"] || [status isEqualToString:@"under_review"]) {
            count += 1;
        }
    }
    return count;
}

- (NSString *)pp_nextRenewalTextForProfile:(PPProviderProfile *)profile {
    if (!profile || !profile.approvedAt) {
        return kLang(@"ProviderSubscriptionCardManagedByConsole");
    }

    NSString *interval = [PPSafeString(profile.billingInterval).lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([interval isEqualToString:@"one_time"] || [interval isEqualToString:@"once"]) {
        return kLang(@"ProviderPlanIntervalOneTime");
    }

    NSDateComponents *components = [[NSDateComponents alloc] init];
    if ([interval isEqualToString:@"yearly"] || [interval isEqualToString:@"annual"]) {
        components.year = 1;
    } else {
        components.month = 1;
    }

    NSDate *renewalDate = [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:profile.approvedAt options:0];
    if (!renewalDate) {
        return kLang(@"ProviderSubscriptionCardManagedByConsole");
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:Language.isRTL ? @"ar" : @"en_US"];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterNoStyle;
    return [formatter stringFromDate:renewalDate] ?: kLang(@"ProviderSubscriptionCardManagedByConsole");
}

- (NSString *)pp_subscriptionPendingTextForCount:(NSUInteger)pendingCount eligibleCount:(NSUInteger)eligibleCount {
    if (pendingCount > 0) {
        return [NSString stringWithFormat:kLang(@"ProviderSubscriptionCardPendingCountFormat"), (unsigned long)pendingCount];
    }
    if (eligibleCount > 0) {
        return [NSString stringWithFormat:kLang(@"ProviderSubscriptionCardEligibleCountFormat"), (unsigned long)eligibleCount];
    }
    return kLang(@"ProviderSubscriptionCardNoPending");
}

- (void)pp_renderSubscriptionFooter {
    [self pp_buildSubscriptionFooterIfNeeded];

    UIColor *accent = AppPrimaryClr ?: UIColor.systemTealColor;
    UIColor *statusColor = accent;
    NSString *pill = kLang(@"ProviderSubscriptionCardChecking");
    NSString *title = kLang(@"ProviderSubscriptionCardTitle");
    NSString *subtitle = kLang(@"ProviderSubscriptionCardLoadingSubtitle");
    NSString *statusValue = kLang(@"ProviderSubscriptionCardChecking");
    NSString *renewalValue = kLang(@"ProviderSubscriptionCardDash");
    NSString *pendingValue = kLang(@"ProviderSubscriptionCardDash");

    PPProviderOnboardingState *state = self.providerSubscriptionState;
    if (self.providerSubscriptionError) {
        statusColor = UIColor.systemRedColor;
        pill = kLang(@"ProviderHeroErrorBadge");
        subtitle = self.providerSubscriptionError.localizedDescription.length ? self.providerSubscriptionError.localizedDescription : kLang(@"ProviderPlansLoadFailed");
        statusValue = kLang(@"ProviderHeroErrorBadge");
        pendingValue = kLang(@"ProviderRetryButton");
    } else if (!self.isProviderSubscriptionLoading && state) {
        PPProviderProfile *activeProfile = [self pp_primaryActiveProviderProfileForState:state];
        NSUInteger pendingCount = [self pp_pendingProviderApplicationCountForState:state];
        NSUInteger eligibleCount = state.eligibleProviderTypes.count;

        if (state.isBlocked) {
            statusColor = UIColor.systemRedColor;
            pill = kLang(@"ProviderHeroBlockedBadge");
            title = kLang(@"ProviderSubscriptionCardBlockedTitle");
            subtitle = kLang(@"ProviderSubscriptionCardBlockedSubtitle");
            statusValue = kLang(@"ProviderHeroBlockedBadge");
            renewalValue = kLang(@"ProviderSubscriptionCardManagedByConsole");
        } else if (activeProfile) {
            statusColor = UIColor.systemGreenColor;
            pill = kLang(@"ProviderStatusActive");
            NSString *planName = activeProfile.localizedPlanName.length ? activeProfile.localizedPlanName : kLang(@"ProviderSubscriptionCardActivePlanFallback");
            title = planName;
            subtitle = kLang(@"ProviderSubscriptionCardActiveSubtitle");
            statusValue = kLang(@"ProviderStatusActive");
            renewalValue = [self pp_nextRenewalTextForProfile:activeProfile];
        } else if (pendingCount > 0) {
            statusColor = UIColor.systemOrangeColor;
            pill = kLang(@"ProviderHeroReviewBadge");
            title = kLang(@"ProviderSubscriptionCardReviewTitle");
            subtitle = kLang(@"ProviderSubscriptionCardReviewSubtitle");
            statusValue = kLang(@"ProviderStatusUnderReview");
            renewalValue = kLang(@"ProviderSubscriptionCardAfterApproval");
        } else {
            pill = kLang(@"ProviderHeroReadyBadge");
            title = kLang(@"ProviderSubscriptionCardReadyTitle");
            subtitle = eligibleCount > 0 ? kLang(@"ProviderSubscriptionCardReadySubtitle") : kLang(@"ProviderSubscriptionCardCompleteSubtitle");
            statusValue = eligibleCount > 0 ? kLang(@"ProviderStatusNotApplied") : kLang(@"ProviderStatusActive");
            renewalValue = eligibleCount > 0 ? kLang(@"ProviderSubscriptionCardAfterApproval") : kLang(@"ProviderSubscriptionCardManagedByConsole");
        }
        pendingValue = [self pp_subscriptionPendingTextForCount:pendingCount eligibleCount:eligibleCount];
    }

    self.subscriptionStatusPillLabel.text = pill;
    self.subscriptionStatusPillLabel.textColor = statusColor;
    self.subscriptionStatusPillLabel.backgroundColor = [statusColor colorWithAlphaComponent:0.10];
    self.subscriptionTitleLabel.text = title;
    self.subscriptionSubtitleLabel.text = subtitle;
    self.subscriptionStatusValueLabel.text = statusValue;
    self.subscriptionStatusValueLabel.textColor = statusColor;
    self.subscriptionRenewalValueLabel.text = renewalValue;
    self.subscriptionPendingValueLabel.text = pendingValue;
    self.subscriptionChevronView.image = [UIImage systemImageNamed:Language.isRTL ? @"chevron.left" : @"chevron.right"];
    self.subscriptionFooterCard.layer.borderColor = [statusColor colorWithAlphaComponent:0.10].CGColor;
    self.subscriptionFooterCard.accessibilityLabel = [NSString stringWithFormat:@"%@. %@. %@", title ?: @"", statusValue ?: @"", subtitle ?: @""];

    [self pp_refreshSubscriptionFooterHeight];
}

- (void)pp_refreshSubscriptionFooterHeight {
    if (!self.subscriptionFooterRoot) return;
    CGFloat targetWidth = MAX(self.tableView.bounds.size.width, self.view.bounds.size.width);
    CGRect frame = self.subscriptionFooterRoot.frame;
    frame.size.width = targetWidth;
    self.subscriptionFooterRoot.frame = frame;
    [self.subscriptionFooterRoot setNeedsLayout];
    [self.subscriptionFooterRoot layoutIfNeeded];
    CGSize targetSize = CGSizeMake(targetWidth, UILayoutFittingCompressedSize.height);
    CGFloat height = [self.subscriptionFooterRoot systemLayoutSizeFittingSize:targetSize
                                                withHorizontalFittingPriority:UILayoutPriorityRequired
                                                      verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
    height = MAX(1.0, height);
    if (fabs(frame.size.height - height) > 0.5) {
        frame.size.height = height;
        self.subscriptionFooterRoot.frame = frame;
        self.tableView.tableFooterView = self.subscriptionFooterRoot;
    }
}

- (void)pp_openSubscriptionManagement {
    [PPFunc pp_playTapEffect];
    if (!UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.10 animations:^{
            self.subscriptionFooterCard.transform = CGAffineTransformMakeScale(0.985, 0.985);
        } completion:^(__unused BOOL finished) {
            [UIView animateWithDuration:0.22
                                  delay:0.0
                 usingSpringWithDamping:0.82
                  initialSpringVelocity:0.4
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                self.subscriptionFooterCard.transform = CGAffineTransformIdentity;
            } completion:nil];
        }];
    }

    PPProviderSubscriptionManagmetVC *controller = [[PPProviderSubscriptionManagmetVC alloc] init];
    controller.prefersAutoPresentBecomeProvider = NO;
    controller.suppressAutoDashboardTransition = YES;
    [self.navigationController pushViewController:controller animated:YES];
}

#pragma mark - Ambient Background Glows

- (void)pp_setupAmbientBackgroundGlows {
    if (self.bgAmbientGlow1) return;

    // Glow 1 — top-trailing, large
    self.bgAmbientGlow1 = [[UIView alloc] init];
    self.bgAmbientGlow1.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgAmbientGlow1.userInteractionEnabled = NO;
    self.bgAmbientGlow1.layer.cornerRadius = 180.0;
    [self.view insertSubview:self.bgAmbientGlow1 atIndex:0];

    // Glow 2 — bottom-leading
    self.bgAmbientGlow2 = [[UIView alloc] init];
    self.bgAmbientGlow2.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgAmbientGlow2.userInteractionEnabled = NO;
    self.bgAmbientGlow2.layer.cornerRadius = 100.0;
    [self.view insertSubview:self.bgAmbientGlow2 atIndex:0];

    // Glow 3 — center-right, small accent
    self.bgAmbientGlow3 = [[UIView alloc] init];
    self.bgAmbientGlow3.translatesAutoresizingMaskIntoConstraints = NO;
    self.bgAmbientGlow3.userInteractionEnabled = NO;
    self.bgAmbientGlow3.layer.cornerRadius = 120.0;
    [self.view insertSubview:self.bgAmbientGlow3 atIndex:0];

    [NSLayoutConstraint activateConstraints:@[
        [self.bgAmbientGlow1.widthAnchor constraintEqualToConstant:360.0],
        [self.bgAmbientGlow1.heightAnchor constraintEqualToConstant:360.0],
        [self.bgAmbientGlow1.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-92.0],
        [self.bgAmbientGlow1.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:104.0],

        [self.bgAmbientGlow2.widthAnchor constraintEqualToConstant:200.0],
        [self.bgAmbientGlow2.heightAnchor constraintEqualToConstant:200.0],
        [self.bgAmbientGlow2.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:48.0],
        [self.bgAmbientGlow2.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-64.0],

        [self.bgAmbientGlow3.widthAnchor constraintEqualToConstant:240.0],
        [self.bgAmbientGlow3.heightAnchor constraintEqualToConstant:240.0],
        [self.bgAmbientGlow3.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:60.0],
        [self.bgAmbientGlow3.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:50.0],
    ]];

    [self pp_updateAmbientGlowsForStyle];
}

- (void)pp_updateAmbientGlowsForStyle {
    UIColor *accent = AppPrimaryClr ?: UIColor.systemTealColor;
    UIColor *secColor = [UIColor colorNamed:@"AppSecColor"];
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;

    UIColor *glow1Color = secColor ?: accent;
    UIColor *glow2Color = accent;

    self.bgAmbientGlow1.backgroundColor =[glow2Color colorWithAlphaComponent:isDark ? 0.04 : 0.08];
    self.bgAmbientGlow1.layer.shadowColor = glow1Color.CGColor;
    self.bgAmbientGlow1.layer.shadowOpacity = isDark ? 0.04 : 0.10;
    self.bgAmbientGlow1.layer.shadowRadius = 64.0;
    self.bgAmbientGlow1.layer.shadowOffset = CGSizeZero;

    self.bgAmbientGlow2.backgroundColor = [glow1Color colorWithAlphaComponent:isDark ? 0.06 : 0.12];
    self.bgAmbientGlow2.layer.shadowColor = glow2Color.CGColor;
    self.bgAmbientGlow2.layer.shadowOpacity = isDark ? 0.03 : 0.08;
    self.bgAmbientGlow2.layer.shadowRadius = 72.0;
    self.bgAmbientGlow2.layer.shadowOffset = CGSizeZero;

    self.bgAmbientGlow3.backgroundColor = AppClearClr;// [glow1Color colorWithAlphaComponent:isDark ? 0.03 : 0.06];
    self.bgAmbientGlow3.layer.shadowColor = AppClearClr.CGColor;//glow1Color.CGColor;
    self.bgAmbientGlow3.layer.shadowOpacity = isDark ? 0.02 : 0.06;
    self.bgAmbientGlow3.layer.shadowRadius = 48.0;
    self.bgAmbientGlow3.layer.shadowOffset = CGSizeZero;
}

#pragma mark - Dashboard Hero Palette

- (UIColor *)pp_dashboardHeroSurfaceColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.071 green:0.073 blue:0.078 alpha:0.965];
        }
        return [UIColor colorWithRed:0.985 green:0.982 blue:0.966 alpha:0.965];
    }];
}

- (UIColor *)pp_dashboardHeroInsetSurfaceColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:1.0 alpha:0.082];
        }
        return [UIColor colorWithRed:1.0 green:1.0 blue:0.985 alpha:0.72];
    }];
}

- (UIColor *)pp_dashboardHeroBorderColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:1.0 alpha:0.115];
        }
        return [UIColor colorWithWhite:1.0 alpha:0.82];
    }];
}

- (UIColor *)pp_dashboardHeroLineColor {
    return [AppPrimaryClrShiner colorWithAlphaComponent:0.6];
}

- (UIColor *)pp_dashboardHeroPulseColor {
    return [AppPageColr colorWithAlphaComponent:0.68];
}

- (UIColor *)pp_dashboardHeroDotColor {
    return [AppPrimaryClr colorWithAlphaComponent:0.36];
}

- (UIColor *)pp_dashboardHeroThreadColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:1.0 alpha:0.16];
        }
        return [UIColor colorWithWhite:0.42 alpha:0.12];
    }];
}

- (UIColor *)pp_dashboardHeroSignalColor {
    UIColor *accent = AppPrimaryClr ?: UIColor.systemTealColor;
    return [accent colorWithAlphaComponent:(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.92 : 0.82];
}

- (UIColor *)pp_dashboardHeroPlateColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:1.0 alpha:0.072];
        }
        return [UIColor colorWithRed:1.0 green:0.998 blue:0.976 alpha:0.84];
    }];
}

- (UIColor *)pp_dashboardAvatarContainerColor {
    return [AppBackgroundClrDarker colorWithAlphaComponent:0.35];
}

- (UIColor *)pp_dashboardHeroShadowColor {
    UIColor *accent = AppPrimaryClr ?: UIColor.systemTealColor;
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    return isDark ? [accent colorWithAlphaComponent:0.55] : [UIColor colorWithWhite:0.0 alpha:0.65];
}

- (void)pp_applyDashboardHeroShadow {
    if (!self.heroShadowView) return;

    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    self.heroShadowView.layer.shadowColor = [self pp_dashboardHeroShadowColor].CGColor;
    self.heroShadowView.layer.shadowOpacity = isDark ? 0.24 : 0.16;
    self.heroShadowView.layer.shadowRadius = isDark ? 26.0 : 30.0;
    self.heroShadowView.layer.shadowOffset = CGSizeMake(0, isDark ? 14.0 : 18.0);

    if (!CGRectIsEmpty(self.heroShadowView.bounds)) {
        UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.heroShadowView.bounds
                                                              cornerRadius:PPAdminDashboardHeroRadius];
        self.heroShadowView.layer.shadowPath = shadowPath.CGPath;
    }
}

- (UIView *)pp_dashboardHeroOrbitRingWithSize:(CGFloat)size accent:(BOOL)accent {
    UIView *ring = [[UIView alloc] init];
    ring.translatesAutoresizingMaskIntoConstraints = NO;
    ring.backgroundColor = UIColor.clearColor;
    ring.userInteractionEnabled = NO;
    ring.layer.cornerRadius = size / 2.0;
    ring.layer.cornerCurve = kCACornerCurveContinuous;
    ring.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    ring.layer.borderColor = [self pp_dashboardHeroThreadColor].CGColor;

    UIView *marker = [[UIView alloc] init];
    marker.translatesAutoresizingMaskIntoConstraints = NO;
    marker.backgroundColor = accent ? [self pp_dashboardHeroSignalColor] : [self pp_dashboardHeroDotColor];
    marker.layer.cornerRadius = accent ? 3.0 : 2.5;
    marker.layer.cornerCurve = kCACornerCurveContinuous;
    marker.userInteractionEnabled = NO;
    marker.tag = 2901;
    [ring addSubview:marker];

    CGFloat markerSize = accent ? 6.0 : 5.0;
    [NSLayoutConstraint activateConstraints:@[
        [ring.widthAnchor constraintEqualToConstant:size],
        [ring.heightAnchor constraintEqualToConstant:size],
        [marker.widthAnchor constraintEqualToConstant:markerSize],
        [marker.heightAnchor constraintEqualToConstant:markerSize],
        [marker.centerXAnchor constraintEqualToAnchor:ring.centerXAnchor],
        [marker.topAnchor constraintEqualToAnchor:ring.topAnchor constant:-1.0],
    ]];

    return ring;
}

- (void)pp_refreshDashboardHeroMaterials {
    self.heroSurfaceView.accentColor = AppPrimaryClr ?: UIColor.systemTealColor;
    [self.heroSurfaceView reapplyPalette];
    [self pp_applyDashboardHeroShadow];

    self.heroLiveLineView.backgroundColor = [self pp_dashboardHeroLineColor];
    self.heroAvatarPulseView.backgroundColor = [self pp_dashboardHeroPulseColor];
    self.heroAvatarContainerView.backgroundColor = [self pp_dashboardAvatarContainerColor];
    self.heroAvatarContainerView.layer.borderColor = [self pp_dashboardHeroBorderColor].CGColor;

    UIColor *dotColor = [self pp_dashboardHeroDotColor];


    UIColor *threadColor = [self pp_dashboardHeroThreadColor];




    [self.heroOrbitRingViews enumerateObjectsUsingBlock:^(UIView *ringView, NSUInteger idx, __unused BOOL *stop) {
        ringView.layer.borderColor = threadColor.CGColor;
        UIView *marker = [ringView viewWithTag:2901];
        marker.backgroundColor = (idx == 0) ? [self pp_dashboardHeroSignalColor] : dotColor;
    }];

    self.heroStatusDotView.backgroundColor = [self pp_dashboardHeroSignalColor];
    self.heroPrimaryActionButton.backgroundColor = AppPrimaryClr ?: UIColor.systemTealColor;
    [self.heroPrimaryActionButton setTitleColor:AppForgroundColr ?: UIColor.whiteColor forState:UIControlStateNormal];
    [self pp_updateDashboardHeroLiveState];
}

- (UIButton *)pp_dashboardHeaderButtonWithSymbol:(NSString *)symbol
                                        selector:(SEL)selector
                              accessibilityLabel:(NSString *)accessibilityLabel {
    UIColor *accentColor = AppPrimaryClr ?: UIColor.systemTealColor;
    UIColor *buttonSurface = AppForgroundColr ?: UIColor.systemBackgroundColor;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = accentColor;
    button.backgroundColor = [buttonSurface colorWithAlphaComponent:0.99];
    button.layer.cornerRadius = PPAdminDashboardActionButtonSize / 2.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    button.layer.borderColor = [accentColor colorWithAlphaComponent:0.10].CGColor;
    button.layer.shadowColor = [accentColor colorWithAlphaComponent:0.18].CGColor;
    button.layer.shadowOpacity = 0.12;
    button.layer.shadowRadius = 14.0;
    button.layer.shadowOffset = CGSizeMake(0, 8);
    button.accessibilityLabel = accessibilityLabel;

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
    UIImage *image = [UIImage systemImageNamed:symbol withConfiguration:config];
    [button setImage:image forState:UIControlStateNormal];
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    [PPButtonHelper attachTapAnimationToButton:button style:PPButtonAnimationStyleDefault];

    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:PPAdminDashboardActionButtonSize],
        [button.heightAnchor constraintEqualToConstant:PPAdminDashboardActionButtonSize],
    ]];

    return button;
}

- (void)pp_buildDashboardHeaderIfNeeded {
    if (self.headerSetupCompleted) return;

    UIColor *accentColor = AppPrimaryClr ?: UIColor.systemTealColor;
    UIColor *surfaceColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    UIColor *heroSurfaceColor = [self pp_dashboardHeroSurfaceColor];
    UIColor *heroInsetSurfaceColor = [self pp_dashboardHeroInsetSurfaceColor];
    UIColor *heroBorderColor = [self pp_dashboardHeroBorderColor];
    UIColor *heroLineColor = [self pp_dashboardHeroLineColor];
    UIColor *heroPulseColor = [self pp_dashboardHeroPulseColor];
    UIColor *secondaryTextColor = SeconderyTextClr ?: UIColor.secondaryLabelColor;
    UIColor *shadowColor = AppShadowColor ?: [UIColor colorWithWhite:0.0 alpha:1.0];

    self.headerRoot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 1)];
    self.headerRoot.backgroundColor = UIColor.clearColor;
    self.headerRoot.clipsToBounds = NO;

    UIView *heroShadowView = [[UIView alloc] init];
    heroShadowView.translatesAutoresizingMaskIntoConstraints = NO;
    heroShadowView.backgroundColor = UIColor.clearColor;
    heroShadowView.clipsToBounds = NO;
    self.heroShadowView = heroShadowView;
    [self pp_applyDashboardHeroShadow];
    [self.headerRoot addSubview:heroShadowView];

    self.heroSurfaceView = [[PPHero alloc] initWithFrame:CGRectZero];
    self.heroSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroSurfaceView.accentColor = accentColor;
    self.headerCard = self.heroSurfaceView;
    [heroShadowView addSubview:self.headerCard];



    UIView *avatarSurface = [[UIView alloc] init];
    avatarSurface.translatesAutoresizingMaskIntoConstraints = NO;
    avatarSurface.backgroundColor = [self pp_dashboardAvatarContainerColor];
    avatarSurface.layer.cornerRadius = 43.0;
    avatarSurface.layer.cornerCurve = kCACornerCurveContinuous;
    avatarSurface.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    avatarSurface.layer.borderColor = heroBorderColor.CGColor;
    avatarSurface.clipsToBounds = YES;
    self.heroAvatarContainerView = avatarSurface;

    self.avatarIMV = [[UIImageView alloc] init];
    self.avatarIMV.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarIMV.backgroundColor = heroInsetSurfaceColor;
    self.avatarIMV.tintColor = secondaryTextColor;
    self.avatarIMV.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarIMV.clipsToBounds = YES;
    self.avatarIMV.layer.cornerRadius = 35.0;
    self.avatarIMV.layer.cornerCurve = kCACornerCurveContinuous;
    self.avatarIMV.userInteractionEnabled = YES;
    [avatarSurface addSubview:self.avatarIMV];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapAddProfilePhoto)];
    [self.avatarIMV addGestureRecognizer:tap];

    self.welcomeLabel = [[UILabel alloc] init];
    self.welcomeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.welcomeLabel.font = [Styling fontMedium:16];
    self.welcomeLabel.textColor = secondaryTextColor;
    self.welcomeLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.welcomeLabel.text = kLang(@"AdminDashboard");
    self.welcomeLabel.numberOfLines = 1;
    self.welcomeLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.welcomeLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [self.welcomeLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self.welcomeLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];

    self.adminNameLabel = [[UILabel alloc] init];
    self.adminNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.adminNameLabel.font = [Styling fontBold:21];
    self.adminNameLabel.textColor = PrimaryTextClr ?: UIColor.labelColor;
    self.adminNameLabel.numberOfLines = 1;
    self.adminNameLabel.textAlignment = Language.alignmentForCurrentLanguage;
    self.adminNameLabel.text = kLang(@"DashboardHero_Command_AllClear");

    self.dashboardSummaryLabel = [[UILabel alloc] init];
    self.dashboardSummaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.dashboardSummaryLabel.font = [Styling fontMedium:12];
    self.dashboardSummaryLabel.textColor = secondaryTextColor;
    self.dashboardSummaryLabel.numberOfLines = 1;
    self.dashboardSummaryLabel.textAlignment = Language.alignmentForCurrentLanguage;

    self.dashboardAccessLabel = [[UILabel alloc] init];
    self.dashboardAccessLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.dashboardAccessLabel.font = [Styling fontMedium:11];
    self.dashboardAccessLabel.textColor = secondaryTextColor;
    self.dashboardAccessLabel.numberOfLines = 2;
    self.dashboardAccessLabel.adjustsFontSizeToFitWidth = NO;
    self.dashboardAccessLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.dashboardAccessLabel.textAlignment = Language.alignmentForCurrentLanguage;
    [self.dashboardAccessLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    self.heroStatusDotView = [[UIView alloc] init];
    self.heroStatusDotView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroStatusDotView.backgroundColor = [self pp_dashboardHeroSignalColor];
    self.heroStatusDotView.layer.cornerRadius = 3.5;
    self.heroStatusDotView.layer.cornerCurve = kCACornerCurveContinuous;
    self.heroStatusDotView.userInteractionEnabled = NO;

    self.heroStatusPillLabel = [[UILabel alloc] init];
    self.heroStatusPillLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroStatusPillLabel.font = [Styling fontBold:10];
    self.heroStatusPillLabel.textColor = PrimaryTextClr ?: UIColor.labelColor;
    self.heroStatusPillLabel.textAlignment = NSTextAlignmentCenter;
    self.heroStatusPillLabel.text = kLang(@"DashboardHero_Status_Live");
    self.heroStatusPillLabel.numberOfLines = 1;

    UIView *statusPillWrap = [[UIView alloc] init];
    statusPillWrap.translatesAutoresizingMaskIntoConstraints = NO;
    statusPillWrap.backgroundColor = [self pp_dashboardHeroPlateColor];
    statusPillWrap.layer.cornerRadius = 14.0;
    statusPillWrap.layer.cornerCurve = kCACornerCurveContinuous;
    statusPillWrap.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    statusPillWrap.layer.borderColor = [self pp_dashboardHeroThreadColor].CGColor;
    statusPillWrap.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
    statusPillWrap.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.18 : 0.045;
    statusPillWrap.layer.shadowRadius = 10.0;
    statusPillWrap.layer.shadowOffset = CGSizeMake(0, 5.0);
    statusPillWrap.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [statusPillWrap setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [statusPillWrap setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [statusPillWrap addSubview:self.heroStatusDotView];
    [statusPillWrap addSubview:self.heroStatusPillLabel];

    UIView *statusRow = [[UIView alloc] init];
    statusRow.translatesAutoresizingMaskIntoConstraints = NO;
    statusRow.backgroundColor = UIColor.clearColor;
    statusRow.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [statusRow addSubview:statusPillWrap];

    self.heroCommandNumberLabel = [[UILabel alloc] init];
    self.heroCommandNumberLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroCommandNumberLabel.font = [Styling fontBold:34];
    self.heroCommandNumberLabel.textColor = PrimaryTextClr ?: UIColor.labelColor;
    self.heroCommandNumberLabel.textAlignment = NSTextAlignmentNatural;
    self.heroCommandNumberLabel.text = @"0";
    self.heroCommandNumberLabel.adjustsFontSizeToFitWidth = YES;
    self.heroCommandNumberLabel.minimumScaleFactor = 0.72;
    [self.heroCommandNumberLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.heroCommandNumberLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    self.heroFulfillmentMetricValueLabel = [[UILabel alloc] init];
    self.heroFulfillmentMetricValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroFulfillmentMetricValueLabel.font = [Styling fontBold:20];
    self.heroFulfillmentMetricValueLabel.textColor = PrimaryTextClr ?: UIColor.labelColor;
    self.heroFulfillmentMetricValueLabel.textAlignment = NSTextAlignmentCenter;
    self.heroFulfillmentMetricValueLabel.text = @"0";

    self.heroFulfillmentMetricTitleLabel = [[UILabel alloc] init];
    self.heroFulfillmentMetricTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroFulfillmentMetricTitleLabel.font = [Styling fontMedium:10];
    self.heroFulfillmentMetricTitleLabel.textColor = secondaryTextColor;
    self.heroFulfillmentMetricTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.heroFulfillmentMetricTitleLabel.text = kLang(@"DashboardHero_Metric_Fulfillment");
    self.heroFulfillmentMetricTitleLabel.numberOfLines = 1;
    self.heroFulfillmentMetricTitleLabel.adjustsFontSizeToFitWidth = YES;
    self.heroFulfillmentMetricTitleLabel.minimumScaleFactor = 0.78;
    self.heroFulfillmentMetricTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.heroFulfillmentMetricTitleLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.heroFulfillmentMetricTitleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];

    self.heroDeliveryMetricValueLabel = [[UILabel alloc] init];
    self.heroDeliveryMetricValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroDeliveryMetricValueLabel.font = [Styling fontBold:20];
    self.heroDeliveryMetricValueLabel.textColor = PrimaryTextClr ?: UIColor.labelColor;
    self.heroDeliveryMetricValueLabel.textAlignment = NSTextAlignmentCenter;
    self.heroDeliveryMetricValueLabel.text = @"0";

    self.heroDeliveryMetricTitleLabel = [[UILabel alloc] init];
    self.heroDeliveryMetricTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroDeliveryMetricTitleLabel.font = [Styling fontMedium:10];
    self.heroDeliveryMetricTitleLabel.textColor = secondaryTextColor;
    self.heroDeliveryMetricTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.heroDeliveryMetricTitleLabel.text = kLang(@"DashboardHero_Metric_Delivery");
    self.heroDeliveryMetricTitleLabel.numberOfLines = 1;
    self.heroDeliveryMetricTitleLabel.adjustsFontSizeToFitWidth = YES;
    self.heroDeliveryMetricTitleLabel.minimumScaleFactor = 0.78;
    self.heroDeliveryMetricTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.heroDeliveryMetricTitleLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.heroDeliveryMetricTitleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];

    UIView *fulfillmentMetricCard = [[UIView alloc] init];
    fulfillmentMetricCard.translatesAutoresizingMaskIntoConstraints = NO;
    fulfillmentMetricCard.backgroundColor = [self pp_dashboardHeroPlateColor];
    fulfillmentMetricCard.layer.cornerRadius = 18.0;
    fulfillmentMetricCard.layer.cornerCurve = kCACornerCurveContinuous;
    fulfillmentMetricCard.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    fulfillmentMetricCard.layer.borderColor = [self pp_dashboardHeroThreadColor].CGColor;
    fulfillmentMetricCard.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
    fulfillmentMetricCard.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.20 : 0.055;
    fulfillmentMetricCard.layer.shadowRadius = 16.0;
    fulfillmentMetricCard.layer.shadowOffset = CGSizeMake(0, 8.0);

    UIView *deliveryMetricCard = [[UIView alloc] init];
    deliveryMetricCard.translatesAutoresizingMaskIntoConstraints = NO;
    deliveryMetricCard.backgroundColor = [self pp_dashboardHeroPlateColor];
    deliveryMetricCard.layer.cornerRadius = 18.0;
    deliveryMetricCard.layer.cornerCurve = kCACornerCurveContinuous;
    deliveryMetricCard.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    deliveryMetricCard.layer.borderColor = [self pp_dashboardHeroThreadColor].CGColor;
    deliveryMetricCard.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:1.0].CGColor;
    deliveryMetricCard.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.20 : 0.055;
    deliveryMetricCard.layer.shadowRadius = 16.0;
    deliveryMetricCard.layer.shadowOffset = CGSizeMake(0, 8.0);

    UIStackView *fulfillmentMetricStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.heroFulfillmentMetricValueLabel,
        self.heroFulfillmentMetricTitleLabel
    ]];
    fulfillmentMetricStack.translatesAutoresizingMaskIntoConstraints = NO;
    fulfillmentMetricStack.axis = UILayoutConstraintAxisVertical;
    fulfillmentMetricStack.alignment = UIStackViewAlignmentCenter;
    fulfillmentMetricStack.distribution = UIStackViewDistributionFill;
    fulfillmentMetricStack.spacing = 1.0;
    fulfillmentMetricStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [fulfillmentMetricCard addSubview:fulfillmentMetricStack];
    fulfillmentMetricStack.hidden = YES;
    UIStackView *deliveryMetricStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.heroDeliveryMetricValueLabel,
        self.heroDeliveryMetricTitleLabel
    ]];
    deliveryMetricStack.translatesAutoresizingMaskIntoConstraints = NO;
    deliveryMetricStack.axis = UILayoutConstraintAxisVertical;
    deliveryMetricStack.alignment = UIStackViewAlignmentCenter;
    deliveryMetricStack.distribution = UIStackViewDistributionFill;
    deliveryMetricStack.spacing = 1.0;
    deliveryMetricStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [deliveryMetricCard addSubview:deliveryMetricStack];
    deliveryMetricCard.hidden = YES;
    UIStackView *metricsStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        fulfillmentMetricCard,
        deliveryMetricCard
    ]];
    metricsStack.translatesAutoresizingMaskIntoConstraints = NO;
    metricsStack.axis = UILayoutConstraintAxisHorizontal;
    metricsStack.alignment = UIStackViewAlignmentFill;
    metricsStack.distribution = UIStackViewDistributionFillEqually;
    metricsStack.spacing = 8.0;
    metricsStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    metricsStack.hidden = YES;
    self.heroPrimaryActionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.heroPrimaryActionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroPrimaryActionButton.titleLabel.font = [Styling fontBold:12];
    self.heroPrimaryActionButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.heroPrimaryActionButton.titleLabel.minimumScaleFactor = 0.78;
    self.heroPrimaryActionButton.backgroundColor = AppPrimaryClr ?: UIColor.systemTealColor;
    [self.heroPrimaryActionButton setTitleColor:AppForgroundColr ?: UIColor.whiteColor forState:UIControlStateNormal];
    self.heroPrimaryActionButton.layer.cornerRadius = 17.0;
    self.heroPrimaryActionButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.heroPrimaryActionButton.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
    [self.heroPrimaryActionButton addTarget:self action:@selector(pp_handleDashboardHeroPrimaryAction) forControlEvents:UIControlEventTouchUpInside];
    [PPButtonHelper attachTapAnimationToButton:self.heroPrimaryActionButton style:PPButtonAnimationStyleDefault];

    UIView *copyPanel = [[UIView alloc] init];
    copyPanel.translatesAutoresizingMaskIntoConstraints = NO;
    copyPanel.backgroundColor = UIColor.clearColor;

    UIView *copyAccentBar = [[UIView alloc] init];
    copyAccentBar.translatesAutoresizingMaskIntoConstraints = NO;
    copyAccentBar.backgroundColor = heroLineColor;
    copyAccentBar.layer.cornerRadius = 2.0;
    copyAccentBar.layer.cornerCurve = kCACornerCurveContinuous;
    copyAccentBar.userInteractionEnabled = NO;
    self.heroLiveLineView = copyAccentBar;
    [copyPanel addSubview:copyAccentBar];

    UIStackView *identityStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.welcomeLabel
    ]];


    identityStack.translatesAutoresizingMaskIntoConstraints = NO;
    identityStack.axis = UILayoutConstraintAxisVertical;
    identityStack.alignment = UIStackViewAlignmentFill;
    identityStack.spacing = 12.0;
    identityStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIStackView *topBarStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        identityStack,
        statusRow
    ]];
    topBarStack.translatesAutoresizingMaskIntoConstraints = NO;
    topBarStack.axis = UILayoutConstraintAxisVertical;
    topBarStack.alignment = UIStackViewAlignmentFill;
    topBarStack.spacing = 6.0;
    topBarStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIStackView *commandRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.heroCommandNumberLabel,
        self.adminNameLabel
    ]];
    commandRow.translatesAutoresizingMaskIntoConstraints = NO;
    commandRow.axis = UILayoutConstraintAxisHorizontal;
    commandRow.alignment = UIStackViewAlignmentCenter;
    commandRow.spacing = 9.0;
    commandRow.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIStackView *summaryStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        commandRow,
        self.dashboardSummaryLabel
    ]];
    summaryStack.translatesAutoresizingMaskIntoConstraints = NO;
    summaryStack.axis = UILayoutConstraintAxisVertical;
    summaryStack.alignment = UIStackViewAlignmentFill;
    summaryStack.spacing = 6.0;
    summaryStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIView *accessPanel = [[UIView alloc] init];
    accessPanel.translatesAutoresizingMaskIntoConstraints = NO;
    accessPanel.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.62];
    accessPanel.layer.cornerRadius = 18.0;
    accessPanel.layer.cornerCurve = kCACornerCurveContinuous;
    accessPanel.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    accessPanel.layer.borderColor = heroBorderColor.CGColor;
    accessPanel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIView *accessIconWrap = [[UIView alloc] init];
    accessIconWrap.translatesAutoresizingMaskIntoConstraints = NO;
    accessIconWrap.backgroundColor = [self pp_dashboardHeroPulseColor];
    accessIconWrap.layer.cornerRadius = 24.0;
    accessIconWrap.layer.cornerCurve = kCACornerCurveContinuous;
    [accessPanel addSubview:accessIconWrap];

    UIImageView *accessIconView = [[UIImageView alloc] init];
    accessIconView.translatesAutoresizingMaskIntoConstraints = NO;
    accessIconView.tintColor = secondaryTextColor;
    accessIconView.contentMode = UIViewContentModeScaleAspectFit;
    UIImageSymbolConfiguration *accessConfig = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold];
    accessIconView.image = [[UIImage systemImageNamed:@"square.grid.2x2.fill"] imageWithConfiguration:accessConfig];
    [accessIconWrap addSubview:accessIconView];
    [accessPanel addSubview:self.dashboardAccessLabel];
    [accessPanel addSubview:self.heroPrimaryActionButton];

    UIStackView *copyColumnStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        topBarStack,
        summaryStack
    ]];
    copyColumnStack.translatesAutoresizingMaskIntoConstraints = NO;
    copyColumnStack.axis = UILayoutConstraintAxisVertical;
    copyColumnStack.alignment = UIStackViewAlignmentFill;
    copyColumnStack.spacing = 10.0;
    copyColumnStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [copyPanel addSubview:copyColumnStack];

    UIView *heroMediaPanel = [[UIView alloc] init];
    heroMediaPanel.translatesAutoresizingMaskIntoConstraints = NO;
    heroMediaPanel.backgroundColor = UIColor.clearColor;
    heroMediaPanel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIView *orbitOuterRing = [self pp_dashboardHeroOrbitRingWithSize:112.0 accent:YES];
    UIView *orbitInnerRing = [self pp_dashboardHeroOrbitRingWithSize:96.0 accent:NO];
    [heroMediaPanel addSubview:orbitOuterRing];
    [heroMediaPanel addSubview:orbitInnerRing];
    self.heroOrbitRingViews = @[orbitOuterRing, orbitInnerRing];

    UIView *heroMediaHalo = [[UIView alloc] init];
    heroMediaHalo.translatesAutoresizingMaskIntoConstraints = NO;
    heroMediaHalo.backgroundColor = heroPulseColor;
    heroMediaHalo.layer.cornerRadius = 48.0;
    heroMediaHalo.layer.cornerCurve = kCACornerCurveContinuous;
    heroMediaHalo.userInteractionEnabled = NO;
    self.heroAvatarPulseView = heroMediaHalo;
    [heroMediaPanel addSubview:heroMediaHalo];

    [heroMediaPanel addSubview:avatarSurface];

    UIStackView *topContentRow = [[UIStackView alloc] initWithArrangedSubviews:@[
        copyPanel,
        heroMediaPanel
    ]];
    topContentRow.translatesAutoresizingMaskIntoConstraints = NO;
    topContentRow.axis = UILayoutConstraintAxisHorizontal;
    topContentRow.alignment = UIStackViewAlignmentFill;
    topContentRow.spacing = 12.0;
    topContentRow.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIStackView *heroBodyStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        topContentRow,
        metricsStack,
        accessPanel
    ]];
    heroBodyStack.translatesAutoresizingMaskIntoConstraints = NO;
    heroBodyStack.axis = UILayoutConstraintAxisVertical;
    heroBodyStack.alignment = UIStackViewAlignmentFill;
    heroBodyStack.spacing = 12.0;
    heroBodyStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.headerCard addSubview:heroBodyStack];
    metricsStack.hidden = YES;
    self.addPhotoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.addPhotoButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *plusConfig = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold];
    UIImage *plusIcon = [UIImage systemImageNamed:@"plus.circle.fill" withConfiguration:plusConfig];
    [self.addPhotoButton setImage:plusIcon forState:UIControlStateNormal];
    self.addPhotoButton.tintColor = accentColor;
    self.addPhotoButton.backgroundColor = heroSurfaceColor;
    self.addPhotoButton.layer.cornerRadius = 12.0;
    self.addPhotoButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.addPhotoButton.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    self.addPhotoButton.layer.borderColor = heroBorderColor.CGColor;
    self.addPhotoButton.layer.shadowColor = shadowColor.CGColor;
    self.addPhotoButton.layer.shadowOpacity = 0.10;
    self.addPhotoButton.layer.shadowRadius = 10.0;
    self.addPhotoButton.layer.shadowOffset = CGSizeMake(0, 6.0);
    self.addPhotoButton.accessibilityLabel = kLang(@"Add profile photo");
    [self.addPhotoButton addTarget:self action:@selector(didTapAddProfilePhoto) forControlEvents:UIControlEventTouchUpInside];
    [avatarSurface addSubview:self.addPhotoButton];

    [NSLayoutConstraint activateConstraints:@[
        [heroShadowView.topAnchor constraintEqualToAnchor:self.headerRoot.topAnchor constant:12.0],
        [heroShadowView.leadingAnchor constraintEqualToAnchor:self.headerRoot.leadingAnchor constant:PPAdminDashboardHorizontalInset],
        [heroShadowView.trailingAnchor constraintEqualToAnchor:self.headerRoot.trailingAnchor constant:-PPAdminDashboardHorizontalInset],

        [self.headerCard.topAnchor constraintEqualToAnchor:heroShadowView.topAnchor],
        [self.headerCard.leadingAnchor constraintEqualToAnchor:heroShadowView.leadingAnchor],
        [self.headerCard.trailingAnchor constraintEqualToAnchor:heroShadowView.trailingAnchor],
        [self.headerCard.bottomAnchor constraintEqualToAnchor:heroShadowView.bottomAnchor],

        [heroBodyStack.topAnchor constraintEqualToAnchor:self.headerCard.topAnchor constant:18.0],
        [heroBodyStack.leadingAnchor constraintEqualToAnchor:self.headerCard.leadingAnchor constant:18.0],
        [heroBodyStack.trailingAnchor constraintEqualToAnchor:self.headerCard.trailingAnchor constant:-18.0],
        [heroBodyStack.bottomAnchor constraintEqualToAnchor:self.headerCard.bottomAnchor constant:-18.0],

        [topContentRow.heightAnchor constraintGreaterThanOrEqualToConstant:124.0],
        [heroMediaPanel.widthAnchor constraintEqualToConstant:118.0],

        [copyAccentBar.topAnchor constraintEqualToAnchor:copyPanel.topAnchor constant:2.0],
        [copyAccentBar.leadingAnchor constraintEqualToAnchor:copyPanel.leadingAnchor],
        [copyAccentBar.bottomAnchor constraintEqualToAnchor:copyPanel.bottomAnchor constant:-2.0],
        [copyAccentBar.widthAnchor constraintEqualToConstant:3.0],

        [copyColumnStack.topAnchor constraintEqualToAnchor:copyPanel.topAnchor],
        [copyColumnStack.leadingAnchor constraintEqualToAnchor:copyPanel.leadingAnchor constant:14.0],
        [copyColumnStack.trailingAnchor constraintEqualToAnchor:copyPanel.trailingAnchor],
        [copyColumnStack.bottomAnchor constraintEqualToAnchor:copyPanel.bottomAnchor],

        [statusPillWrap.topAnchor constraintEqualToAnchor:statusRow.topAnchor],
         [statusPillWrap.bottomAnchor constraintEqualToAnchor:statusRow.bottomAnchor],
        [statusPillWrap.leadingAnchor constraintGreaterThanOrEqualToAnchor:statusRow.leadingAnchor],

        [self.heroStatusDotView.leadingAnchor constraintEqualToAnchor:statusPillWrap.leadingAnchor constant:10.0],
        [self.heroStatusDotView.centerYAnchor constraintEqualToAnchor:statusPillWrap.centerYAnchor],
        [self.heroStatusDotView.widthAnchor constraintEqualToConstant:7.0],
        [self.heroStatusDotView.heightAnchor constraintEqualToConstant:7.0],

        [self.heroStatusPillLabel.topAnchor constraintEqualToAnchor:statusPillWrap.topAnchor constant:6.0],
        [self.heroStatusPillLabel.leadingAnchor constraintEqualToAnchor:self.heroStatusDotView.trailingAnchor constant:6.0],
        [self.heroStatusPillLabel.trailingAnchor constraintEqualToAnchor:statusPillWrap.trailingAnchor constant:-10.0],
        [self.heroStatusPillLabel.bottomAnchor constraintEqualToAnchor:statusPillWrap.bottomAnchor constant:-6.0],

        [metricsStack.heightAnchor constraintEqualToConstant:52.0],

        [fulfillmentMetricStack.topAnchor constraintEqualToAnchor:fulfillmentMetricCard.topAnchor constant:8.0],
        [fulfillmentMetricStack.leadingAnchor constraintEqualToAnchor:fulfillmentMetricCard.leadingAnchor constant:12.0],
        [fulfillmentMetricStack.trailingAnchor constraintEqualToAnchor:fulfillmentMetricCard.trailingAnchor constant:-12.0],
        [fulfillmentMetricStack.bottomAnchor constraintEqualToAnchor:fulfillmentMetricCard.bottomAnchor constant:-8.0],

        [deliveryMetricStack.topAnchor constraintEqualToAnchor:deliveryMetricCard.topAnchor constant:8.0],
        [deliveryMetricStack.leadingAnchor constraintEqualToAnchor:deliveryMetricCard.leadingAnchor constant:12.0],
        [deliveryMetricStack.trailingAnchor constraintEqualToAnchor:deliveryMetricCard.trailingAnchor constant:-12.0],
        [deliveryMetricStack.bottomAnchor constraintEqualToAnchor:deliveryMetricCard.bottomAnchor constant:-8.0],

        [accessPanel.heightAnchor constraintGreaterThanOrEqualToConstant:74.0],

        [accessIconWrap.leadingAnchor constraintEqualToAnchor:accessPanel.leadingAnchor constant:14.0],
        [accessIconWrap.centerYAnchor constraintEqualToAnchor:accessPanel.centerYAnchor],
        [accessIconWrap.widthAnchor constraintEqualToConstant:48.0],
        [accessIconWrap.heightAnchor constraintEqualToConstant:48.0],

        [accessIconView.centerXAnchor constraintEqualToAnchor:accessIconWrap.centerXAnchor],
        [accessIconView.centerYAnchor constraintEqualToAnchor:accessIconWrap.centerYAnchor],
        [accessIconView.widthAnchor constraintEqualToConstant:18.0],
        [accessIconView.heightAnchor constraintEqualToConstant:18.0],

        [self.dashboardAccessLabel.leadingAnchor constraintEqualToAnchor:accessIconWrap.trailingAnchor constant:12.0],
        [self.dashboardAccessLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroPrimaryActionButton.leadingAnchor constant:-12.0],
        [self.dashboardAccessLabel.centerYAnchor constraintEqualToAnchor:accessPanel.centerYAnchor],
        [self.dashboardAccessLabel.topAnchor constraintGreaterThanOrEqualToAnchor:accessPanel.topAnchor constant:12.0],
        [self.dashboardAccessLabel.bottomAnchor constraintLessThanOrEqualToAnchor:accessPanel.bottomAnchor constant:-12.0],

        [self.heroPrimaryActionButton.centerYAnchor constraintEqualToAnchor:accessPanel.centerYAnchor],
        [self.heroPrimaryActionButton.heightAnchor constraintEqualToConstant:34.0],
        [self.heroPrimaryActionButton.trailingAnchor constraintEqualToAnchor:accessPanel.trailingAnchor constant:-14.0],
        [self.heroPrimaryActionButton.widthAnchor constraintGreaterThanOrEqualToConstant:96.0],

        [orbitOuterRing.centerXAnchor constraintEqualToAnchor:heroMediaPanel.centerXAnchor],
        [orbitOuterRing.centerYAnchor constraintEqualToAnchor:heroMediaPanel.centerYAnchor],
        [orbitInnerRing.centerXAnchor constraintEqualToAnchor:heroMediaPanel.centerXAnchor],
        [orbitInnerRing.centerYAnchor constraintEqualToAnchor:heroMediaPanel.centerYAnchor],

        [heroMediaHalo.centerXAnchor constraintEqualToAnchor:heroMediaPanel.centerXAnchor],
        [heroMediaHalo.centerYAnchor constraintEqualToAnchor:heroMediaPanel.centerYAnchor],
        [heroMediaHalo.widthAnchor constraintEqualToConstant:96.0],
        [heroMediaHalo.heightAnchor constraintEqualToConstant:96.0],

        [avatarSurface.centerXAnchor constraintEqualToAnchor:heroMediaPanel.centerXAnchor],
        [avatarSurface.centerYAnchor constraintEqualToAnchor:heroMediaPanel.centerYAnchor],
        [avatarSurface.widthAnchor constraintEqualToConstant:86.0],
        [avatarSurface.heightAnchor constraintEqualToConstant:86.0],

        [self.avatarIMV.topAnchor constraintEqualToAnchor:avatarSurface.topAnchor constant:8.0],
        [self.avatarIMV.leadingAnchor constraintEqualToAnchor:avatarSurface.leadingAnchor constant:8.0],
        [self.avatarIMV.trailingAnchor constraintEqualToAnchor:avatarSurface.trailingAnchor constant:-8.0],
        [self.avatarIMV.bottomAnchor constraintEqualToAnchor:avatarSurface.bottomAnchor constant:-8.0],

        [self.addPhotoButton.widthAnchor constraintEqualToConstant:24.0],
        [self.addPhotoButton.heightAnchor constraintEqualToConstant:24.0],
        [self.addPhotoButton.trailingAnchor constraintEqualToAnchor:avatarSurface.trailingAnchor constant:-2.0],
        [self.addPhotoButton.bottomAnchor constraintEqualToAnchor:avatarSurface.bottomAnchor constant:-2.0],
    ]];

    self.quickActionsView = [[PPQuickActionsView alloc] init];
    self.quickActionsView.translatesAutoresizingMaskIntoConstraints = NO;
    self.quickActionsView.backgroundColorForButton = [AppForgroundColr colorWithAlphaComponent:0.62];
    self.quickActionsView.tintColorForIcon = accentColor;
    self.quickActionsView.cornerRadius = 24.0;
    self.quickActionsView.buttonHeight = 58.0;
    [self.headerRoot addSubview:self.quickActionsView];

    self.quickActionsRailStyle = [self pp_isDeliveryCompanyOnlyDashboardForUser:[self pp_activeDashboardUser]] && self.isDeliveryCompanyMode
        ? PPDashboardQuickActionRailStyleDeliveryMember
        : PPDashboardQuickActionRailStyleOwner;

    self.quickActionsRailContainer = [[UIView alloc] init];
    self.quickActionsRailContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.quickActionsRailContainer.backgroundColor = UIColor.clearColor;
    [self.headerRoot addSubview:self.quickActionsRailContainer];

    self.quickActionsRailView = [[PPQuickActionsRailView alloc] init];
    self.quickActionsRailView.translatesAutoresizingMaskIntoConstraints = NO;
    self.quickActionsRailView.tintColorForIcons = accentColor;
    self.quickActionsRailView.style = self.quickActionsRailStyle;
    self.quickActionsRailView.titleKey = @"DashboardQuickActions_Title";
    self.quickActionsRailView.subtitleKey = @"DashboardQuickActions_Subtitle";
    self.quickActionsRailView.trailingTitleKey = @"DashboardQuickActions_ViewAll";
    __weak typeof(self) weakSelf = self;
    self.quickActionsRailView.trailingHandler = ^{
        [weakSelf pp_openProfileSettings];
    };
    [self.quickActionsRailContainer addSubview:self.quickActionsRailView];

    [NSLayoutConstraint activateConstraints:@[
        
        [self.quickActionsView.topAnchor constraintEqualToAnchor:heroShadowView.bottomAnchor constant:14.0],
        [self.quickActionsView.leadingAnchor constraintEqualToAnchor:self.headerRoot.leadingAnchor constant:PPAdminDashboardHorizontalInset],
        [self.quickActionsView.trailingAnchor constraintEqualToAnchor:self.headerRoot.trailingAnchor constant:-PPAdminDashboardHorizontalInset],

        
        [self.quickActionsRailContainer.topAnchor constraintEqualToAnchor:self.quickActionsView.bottomAnchor constant:8.0],
        [self.quickActionsRailContainer.leadingAnchor constraintEqualToAnchor:self.headerRoot.leadingAnchor constant:PPAdminDashboardHorizontalInset],
        [self.quickActionsRailContainer.trailingAnchor constraintEqualToAnchor:self.headerRoot.trailingAnchor constant:-PPAdminDashboardHorizontalInset],
        [self.quickActionsRailContainer.bottomAnchor constraintEqualToAnchor:self.headerRoot.bottomAnchor constant:-12],
        
        
        [self.quickActionsRailView.topAnchor constraintEqualToAnchor:self.quickActionsRailContainer.topAnchor],
        [self.quickActionsRailView.leadingAnchor constraintEqualToAnchor:self.quickActionsRailContainer.leadingAnchor],
        [self.quickActionsRailView.trailingAnchor constraintEqualToAnchor:self.quickActionsRailContainer.trailingAnchor],
        [self.quickActionsRailView.bottomAnchor constraintEqualToAnchor:self.quickActionsRailContainer.bottomAnchor],
        [self.quickActionsRailView.heightAnchor constraintEqualToConstant:188.0],

     
    ]];

    self.tableView.tableHeaderView = self.headerRoot;
    self.headerSetupCompleted = YES;
    [self pp_updateDashboardHeroLiveState];
}

- (NSArray<PPQuickActionItem *> *)pp_dashboardQuickActions {
    __weak typeof(self) weakSelf = self;
    NSMutableArray<PPQuickActionItem *> *items = [NSMutableArray array];
    UserModel *dashboardUser = [self pp_activeDashboardUser];

    BOOL canManageServices = [self pp_canManageServices];
    BOOL canManageMarketplace = [self pp_canManageMarketplace];
    BOOL canManagePharmacy = [self pp_canManagePharmacy];
    BOOL canManageDelivery = [self pp_canManageDelivery];
    BOOL canManageVets = [self pp_canManageVets];
    BOOL canManageAdoption = [self pp_canManageAdoption];
    PPDeliveryCompanyProfile *profile = self.deliveryCompanyContext;

    PPDeliveryCompanyRequest *activeRequest = (self.isDeliveryCompanyMode && profile.isDriver) ? [self pp_activeDeliveryCompanyRequest] : nil;
    if (activeRequest.requestID.length > 0) {
        [items addObject:[PPQuickActionItem itemWithTitleKey:@"DeliveryCompany_DashboardShell_ContinueActive"
                                                subtitleKey:@"DeliveryCompany_DashboardShell_ContinueActiveSubtitle"
                                                   iconName:@"location.fill"
                                                      width:0
                                                    handler:^{
            [PPFunc pp_playTapEffect];
            PPDeliveryCompanyDetailViewController *controller =
                [[PPDeliveryCompanyDetailViewController alloc] initWithRequestID:activeRequest.requestID
                                                                         profile:profile];
            [weakSelf.navigationController pushViewController:controller animated:YES];
        }]];
    }

    if (canManageServices || canManageMarketplace) {
        NSInteger pendingCount = self.fulfillmentNewRequestsCount;
        PPQuickActionItem *fulfillmentItem = [PPQuickActionItem itemWithTitleKey:@"Fulfillment_Title"
                                                                     subtitleKey:@"Fulfillment_EmptySubtitle"
                                                                        iconName:@"shippingbox.fill"
                                                                           width:0
                                                                         handler:^{
            [PPFunc pp_playTapEffect];
            [weakSelf pp_markQuickActionKindSeen:PPAdminQuickActionSignalFulfillment];
            PPFulfillmentListViewController *vc = [[PPFulfillmentListViewController alloc] init];
            [weakSelf.navigationController pushViewController:vc animated:YES];
        }];
        fulfillmentItem.showsBreathingDot = (pendingCount > 0) || self.hasUnseenFulfillmentQuickAction;
        fulfillmentItem.badgeText = pendingCount > 0 ? [NSString stringWithFormat:@"%ld", (long)pendingCount] : nil;
        [items addObject:fulfillmentItem];
    }

    if ([self pp_isDeliveryCompanyOnlyDashboardForUser:dashboardUser] && self.isDeliveryCompanyMode) {
        PPDeliveryCompanyProfile *profile = self.deliveryCompanyContext;
        [items addObject:[PPQuickActionItem itemWithTitleKey:(profile.isDriver
                                                                  ? @"DeliveryCompany_DashboardShell_MyAssigned"
                                                                  : @"DeliveryCompany_Title")
                                                subtitleKey:(profile.isDriver
                                                                  ? @"DeliveryCompany_DashboardShell_MyAssignedSubtitle"
                                                                  : @"DeliveryCompany_DashboardShell_OpenCompanySubtitle")
                                                   iconName:@"truck.box.fill"
                                                      width:0
                                                    handler:^{
            [weakSelf pp_openDeliveryCompanyDashboard];
        }]];

        PPDeliveryCompanyRequest *activeRequest = profile.isDriver ? [self pp_activeDeliveryCompanyRequest] : nil;
        if (activeRequest.requestID.length > 0) {
            [items addObject:[PPQuickActionItem itemWithTitleKey:@"DeliveryCompany_DashboardShell_ContinueActive"
                                                    subtitleKey:@"DeliveryCompany_DashboardShell_ContinueActiveSubtitle"
                                                       iconName:@"location.fill"
                                                          width:0
                                                        handler:^{
                [PPFunc pp_playTapEffect];
                PPDeliveryCompanyDetailViewController *controller =
                    [[PPDeliveryCompanyDetailViewController alloc] initWithRequestID:activeRequest.requestID
                                                                             profile:profile];
                [weakSelf.navigationController pushViewController:controller animated:YES];
            }]];
        } else if (profile.canViewMembers) {
            [items addObject:[PPQuickActionItem itemWithTitleKey:@"DeliveryCompany_Tab_Members"
                                                    subtitleKey:@"DeliveryCompany_Dashboard_MembersShortcutSubtitle"
                                                       iconName:@"person.3.fill"
                                                          width:0
                                                        handler:^{
                [weakSelf pp_openDeliveryCompanyMembers];
            }]];
        }

        [items addObject:[PPQuickActionItem itemWithTitleKey:@"Notifications"
                                                subtitleKey:@"NoNewNotifications"
                                                   iconName:@"bell.badge.fill"
                                                      width:0
                                                    handler:^{
            [PPFunc pp_playTapEffect];
            NotificationsListViewController *controller = [[NotificationsListViewController alloc] init];
            [weakSelf.navigationController pushViewController:controller animated:YES];
        }]];

        [items addObject:[PPQuickActionItem itemWithTitleKey:@"ProfileSettings"
                                                subtitleKey:@"ProfileSettingsSubtitle"
                                                   iconName:@"person.crop.circle.fill"
                                                      width:0
                                                    handler:^{
            [weakSelf pp_openProfileSettings];
        }]];
        return items.copy;
    }


    if (canManageMarketplace) {
        [items addObject:[PPQuickActionItem itemWithTitleKey:@"Market_Title"
                                                 subtitleKey:@"Market_EmptySubtitle"
                                                    iconName:@"bag.fill"
                                                       width:0
                                                     handler:^{
            [PPFunc pp_playTapEffect];
            PPProviderMarketItemsViewController *vc = [[PPProviderMarketItemsViewController alloc] init];
            [weakSelf.navigationController pushViewController:vc animated:YES];
        }]];
    }

    if (canManagePharmacy) {
        [items addObject:[PPQuickActionItem itemWithTitleKey:@"Pharmacy_Manage_Title"
                                                 subtitleKey:@"Pharmacy_Manage_Subtitle"
                                                    iconName:@"pills.fill"
                                                       width:0
                                                     handler:^{
            [PPFunc pp_playTapEffect];
            PPPharmacyMedicinesViewController *vc = [[PPPharmacyMedicinesViewController alloc] init];
            [weakSelf.navigationController pushViewController:vc animated:YES];
        }]];
    }

    if (canManageServices) {
       /* [items addObject:[PPQuickActionItem itemWithTitleKey:@"ManageServices"
                                                 subtitleKey:@"ProviderTypeServiceSubtitle"
                                                    iconName:@"scissors"
                                                       width:0
                                                     handler:^{
            [PPFunc pp_playTapEffect];
            PPServicesListViewController *vc = [[PPServicesListViewController alloc] init];
            [weakSelf.navigationController pushViewController:vc animated:YES];
        }]];*/
    }

    if (canManageVets) {
        [items addObject:[PPQuickActionItem itemWithTitleKey:@"Vet_Manage_Title"
                                                 subtitleKey:@"Vet_Manage_Subtitle"
                                                    iconName:@"cross.case.fill"
                                                       width:0
                                                     handler:^{
            [PPFunc pp_playTapEffect];
            PPVetsListViewController *vc = [[PPVetsListViewController alloc] init];
            [weakSelf.navigationController pushViewController:vc animated:YES];
        }]];
    }

    if ([self pp_hasDeliveryCompanyWorkspaceForUser:dashboardUser]) {
        BOOL hasVerifiedCompany = self.isDeliveryCompanyMode && profile.companyID.length > 0;
        NSString *titleKey = hasVerifiedCompany
            ? (profile.isDriver ? @"DeliveryCompany_DashboardShell_MyAssigned" : @"DeliveryCompany_Title")
            : @"DeliveryCompany_SetupEntry_Title";
        NSString *subtitleKey = hasVerifiedCompany
            ? (profile.isDriver ? @"DeliveryCompany_DashboardShell_MyAssignedSubtitle" : @"DeliveryCompany_DashboardShell_OpenCompanySubtitle")
            : @"DeliveryCompany_SetupEntry_Subtitle";
        NSString *iconName = hasVerifiedCompany ? @"truck.box.fill" : @"building.2.crop.circle";
        [items addObject:[PPQuickActionItem itemWithTitleKey:titleKey
                                                 subtitleKey:subtitleKey
                                                    iconName:iconName
                                                       width:0
                                                     handler:^{
            [PPFunc pp_playTapEffect];
            if (weakSelf.isDeliveryCompanyMode) {
                [weakSelf pp_openDeliveryCompanyDashboard];
                return;
            }
            PPDeliveryCompanySetupViewController *vc = [[PPDeliveryCompanySetupViewController alloc] init];
            [weakSelf.navigationController pushViewController:vc animated:YES];
        }]];
    }

    if (canManageDelivery) {
        PPQuickActionItem *deliveryItem = [PPQuickActionItem itemWithTitleKey:@"DeliveryManagement"
                                                                  subtitleKey:@"DeliveryManagementSubtitle"
                                                                     iconName:@"shippingbox.fill"
                                                                        width:0
                                                                      handler:^{
            [PPFunc pp_playTapEffect];
            [weakSelf pp_markQuickActionKindSeen:PPAdminQuickActionSignalDelivery];
            PPDeliveryDashboardViewController *vc = [[PPDeliveryDashboardViewController alloc] init];
            [weakSelf.navigationController pushViewController:vc animated:YES];
        }];
        deliveryItem.showsBreathingDot = self.hasUnseenDeliveryQuickAction;
        [items addObject:deliveryItem];
    }

    if (canManageAdoption) {
        [items addObject:[PPQuickActionItem itemWithTitleKey:@"AdoptPetsTitle"
                                                 subtitleKey:@"AdoptPetsSubtitle"
                                                    iconName:@"heart.fill"
                                                       width:0
                                                     handler:^{
            [PPFunc pp_playTapEffect];
            PPAdoptPetsListViewController *vc = [[PPAdoptPetsListViewController alloc] init];
            [weakSelf.navigationController pushViewController:vc animated:YES];
        }]];
    }

    [items addObject:[PPQuickActionItem itemWithTitleKey:@"Notifications"
                                             subtitleKey:@"NoNewNotifications"
                                                iconName:@"bell.badge.fill"
                                                   width:0
                                                 handler:^{
        [PPFunc pp_playTapEffect];
        NotificationsListViewController *vc = [[NotificationsListViewController alloc] init];
        [weakSelf.navigationController pushViewController:vc animated:YES];
    }]];

    if (items.count > PPAdminDashboardMaxQuickActionCount) {
        return [items subarrayWithRange:NSMakeRange(0, PPAdminDashboardMaxQuickActionCount)];
    }
    return items.copy;
}

- (void)pp_refreshQuickActions {
    NSArray<PPQuickActionItem *> *gridActions = [self pp_dashboardQuickActions];
    NSArray<PPDashboardQuickActionRailItem *> *railActions = [self pp_dashboardQuickActionsRail];
    NSArray<PPDashboardQuickActionRailItem *> *filteredRailActions = [self pp_dashboardRailActions:railActions
                                                                              excludingGridActions:gridActions];

    [self.quickActionsView setActions:gridActions];
    [self quickActionsRailView].actions = filteredRailActions;
    [[self quickActionsRailView] reloadActions];

    // Dynamically update the Fulfillment List row descriptor's badge in the form
    XLFormRowDescriptor *fulfillmentRow = [self.form formRowWithTag:@"fulfillmentOrders"];
    if (fulfillmentRow) {
        NSMutableDictionary *dict = [fulfillmentRow.value mutableCopy] ?: [NSMutableDictionary dictionary];
        if (self.fulfillmentNewRequestsCount > 0) {
            dict[@"badgeText"] = [NSString stringWithFormat:@"%ld", (long)self.fulfillmentNewRequestsCount];
        } else {
            dict[@"badgeText"] = @"0";
        }
        fulfillmentRow.value = dict;
        [self reloadFormRow:fulfillmentRow];
    }
}

- (NSString *)pp_dashboardActionSignatureWithTitleKey:(NSString *)titleKey iconName:(NSString *)iconName {
    NSString *title = [[titleKey ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
    NSString *icon = [[iconName ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
    if (title.length == 0 && icon.length == 0) {
        return @"";
    }
    return [NSString stringWithFormat:@"%@|%@", title, icon];
}

- (NSArray<PPDashboardQuickActionRailItem *> *)pp_dashboardRailActions:(NSArray<PPDashboardQuickActionRailItem *> *)railActions
                                              excludingGridActions:(NSArray<PPQuickActionItem *> *)gridActions {
    if (railActions.count == 0 || gridActions.count == 0) {
        return railActions ?: @[];
    }

    NSMutableSet<NSString *> *gridSignatures = [NSMutableSet set];
    for (PPQuickActionItem *gridItem in gridActions) {
        NSString *signature = [self pp_dashboardActionSignatureWithTitleKey:gridItem.titleKey iconName:gridItem.iconName];
        if (signature.length > 0) {
            [gridSignatures addObject:signature];
        }
    }

    if (gridSignatures.count == 0) {
        return railActions ?: @[];
    }

    NSMutableArray<PPDashboardQuickActionRailItem *> *filtered = [NSMutableArray arrayWithCapacity:railActions.count];
    for (PPDashboardQuickActionRailItem *railItem in railActions) {
        NSString *signature = [self pp_dashboardActionSignatureWithTitleKey:railItem.titleKey iconName:railItem.iconName];
        if (signature.length == 0 || ![gridSignatures containsObject:signature]) {
            [filtered addObject:railItem];
        }
    }
    return filtered.copy;
}

- (NSArray<PPDashboardQuickActionRailItem *> *)pp_dashboardQuickActionsRail {
    __weak typeof(self) weakSelf = self;
    NSMutableArray<PPDashboardQuickActionRailItem *> *items = [NSMutableArray array];
    UserModel *dashboardUser = [self pp_activeDashboardUser];

    if ([self pp_isDeliveryCompanyOnlyDashboardForUser:dashboardUser] && self.isDeliveryCompanyMode) {
        PPDeliveryCompanyProfile *profile = self.deliveryCompanyContext;

        if (profile.isDriver) {
            PPDeliveryCompanyRequest *activeRequest = [self pp_activeDeliveryCompanyRequest];
            if (activeRequest.requestID.length > 0) {
                [items addObject:[PPDashboardQuickActionRailItem itemWithTitleKey:@"DeliveryCompany_DashboardShell_ContinueActive"
                                                         subtitleKey:@"DeliveryCompany_DashboardShell_ContinueActiveSubtitle"
                                                            iconName:@"location.fill"
                                                          badgeText:nil
                                                             enabled:YES
                                                            chevron:YES
                                                             handler:^{
                    [PPFunc pp_playTapEffect];
                    PPDeliveryCompanyDetailViewController *controller =
                        [[PPDeliveryCompanyDetailViewController alloc] initWithRequestID:activeRequest.requestID
                                                                             profile:profile];
                    [weakSelf.navigationController pushViewController:controller animated:YES];
                }]];
            }

            NSInteger assignedCount = [self pp_deliveryCompanyCountForStatuses:@[PPDeliveryCompanyStatusAssigned]];
            NSInteger inTransitCount = [self pp_deliveryCompanyCountForStatuses:@[PPDeliveryCompanyStatusPickedUp, PPDeliveryCompanyStatusInTransit]];
            NSString *badge = (assignedCount + inTransitCount) > 0 ? [NSString stringWithFormat:@"%ld", (long)(assignedCount + inTransitCount)] : nil;

            [items addObject:[PPDashboardQuickActionRailItem itemWithTitleKey:@"DeliveryCompany_DashboardShell_MyAssigned"
                                                     subtitleKey:@"DeliveryCompany_DashboardShell_MyAssignedSubtitle"
                                                        iconName:@"truck.box.fill"
                                                      badgeText:badge
                                                         enabled:YES
                                                        chevron:YES
                                                         handler:^{
                [weakSelf pp_openDeliveryCompanyDashboard];
            }]];
        } else {
            NSInteger offeredCount = [self pp_deliveryCompanyCountForStatuses:@[PPDeliveryCompanyStatusOffered]];
            NSString *badge = offeredCount > 0 ? [NSString stringWithFormat:@"%ld", (long)offeredCount] : nil;

            [items addObject:[PPDashboardQuickActionRailItem itemWithTitleKey:@"DeliveryCompany_Title"
                                                     subtitleKey:@"DeliveryCompany_DashboardShell_OpenCompanySubtitle"
                                                        iconName:@"truck.box.fill"
                                                      badgeText:badge
                                                         enabled:YES
                                                        chevron:YES
                                                         handler:^{
                [weakSelf pp_openDeliveryCompanyDashboard];
            }]];
        }

        if (profile.canViewMembers) {
            [items addObject:[PPDashboardQuickActionRailItem itemWithTitleKey:@"DeliveryCompany_Tab_Members"
                                                     subtitleKey:@"DeliveryCompany_Dashboard_MembersShortcutSubtitle"
                                                        iconName:@"person.3.fill"
                                                      badgeText:nil
                                                         enabled:YES
                                                        chevron:YES
                                                         handler:^{
                [weakSelf pp_openDeliveryCompanyMembers];
            }]];
        }

        [items addObject:[PPDashboardQuickActionRailItem itemWithTitleKey:@"Notifications"
                                                 subtitleKey:@"NoNewNotifications"
                                                    iconName:@"bell.badge.fill"
                                                  badgeText:nil
                                                     enabled:YES
                                                    chevron:YES
                                                     handler:^{
            [PPFunc pp_playTapEffect];
            NotificationsListViewController *controller = [[NotificationsListViewController alloc] init];
            [weakSelf.navigationController pushViewController:controller animated:YES];
        }]];

        NSString *supportChatsBadge = self.supportChatsUnreadThreadsCount > 0 ? [NSString stringWithFormat:@"%ld", (long)self.supportChatsUnreadThreadsCount] : nil;
        [items addObject:[PPDashboardQuickActionRailItem itemWithTitleKey:@"DashboardQuickActions_SupportTitle"
                                                 subtitleKey:@"DashboardQuickActions_SupportSubtitle"
                                                    iconName:@"message.badge.fill"
                                                  badgeText:supportChatsBadge
                                                     enabled:YES
                                                    chevron:YES
                                                     handler:^{
            [weakSelf pp_openSupportChats];
        }]];

        [items addObject:[PPDashboardQuickActionRailItem itemWithTitleKey:@"ProfileSettings"
                                                 subtitleKey:@"ProfileSettingsSubtitle"
                                                    iconName:@"person.crop.circle.fill"
                                                  badgeText:nil
                                                     enabled:YES
                                                    chevron:YES
                                                     handler:^{
            [weakSelf pp_openProfileSettings];
        }]];

        return items.copy;
    }

    BOOL canManageServices = [self pp_canManageServices];
    BOOL canManageMarketplace = [self pp_canManageMarketplace];
    BOOL canManagePharmacy = [self pp_canManagePharmacy];
    BOOL canManageDelivery = [self pp_canManageDelivery];
    BOOL canManageVets = [self pp_canManageVets];
    BOOL canManageAdoption = [self pp_canManageAdoption];
    PPDeliveryCompanyProfile *profile = self.deliveryCompanyContext;
    BOOL hasProviderWorkspace = [self pp_hasDeliveryCompanyWorkspaceForUser:dashboardUser] ||
        canManageServices || canManageMarketplace || canManageDelivery || canManageVets || canManagePharmacy || canManageAdoption;

    if (canManageMarketplace) {
        [items addObject:[PPDashboardQuickActionRailItem itemWithTitleKey:@"MarketplaceBranches_Manage"
                                                 subtitleKey:@"MarketplaceBranches_ProfileRowSubtitle"
                                                    iconName:@"building.2.crop.circle"
                                                  badgeText:nil
                                                     enabled:YES
                                                    chevron:YES
                                                     handler:^{
            PPMarketplaceBranchesViewController *vc = [[PPMarketplaceBranchesViewController alloc] init];
            [weakSelf.navigationController pushViewController:vc animated:YES];
        }]];
    }

    if (hasProviderWorkspace) {
        [items addObject:[PPDashboardQuickActionRailItem itemWithTitleKey:@"DashboardQuickActions_CompanyProfileTitle"
                                                 subtitleKey:@"DashboardQuickActions_CompanyProfileSubtitle"
                                                    iconName:@"building.2.fill"
                                                  badgeText:nil
                                                     enabled:YES
                                                    chevron:YES
                                                     handler:^{
            [weakSelf pp_openProfileSettings];
        }]];

        [items addObject:[PPDashboardQuickActionRailItem itemWithTitleKey:@"ProfileSettings_EditProviderProfile"
                                                 subtitleKey:@"DashboardQuickActions_EditProfileSubtitle"
                                                    iconName:@"square.and.pencil"
                                                  badgeText:nil
                                                     enabled:YES
                                                    chevron:YES
                                                     handler:^{
            [weakSelf pp_openProviderProfileEditor];
        }]];
    }

    if (canManageServices || canManageMarketplace) {
        NSInteger pendingCount = [self pp_pendingOrdersCount];
        [items addObject:[PPDashboardQuickActionRailItem itemWithTitleKey:@"Fulfillment_Title"
                                                 subtitleKey:@"DashboardQuickActions_OrdersSubtitle"
                                                    iconName:@"shippingbox.fill"
                                                  badgeText:(pendingCount > 0 ? [NSString stringWithFormat:@"%ld", (long)pendingCount] : nil)
                                                     enabled:YES
                                                    chevron:YES
                                                     handler:^{
            [PPFunc pp_playTapEffect];
            [weakSelf pp_markQuickActionKindSeen:PPAdminQuickActionSignalFulfillment];
            PPFulfillmentListViewController *vc = [[PPFulfillmentListViewController alloc] init];
            [weakSelf.navigationController pushViewController:vc animated:YES];
        }]];
    }

    if (canManageMarketplace) {
        [items addObject:[PPDashboardQuickActionRailItem itemWithTitleKey:@"Market_Title"
                                                 subtitleKey:@"DashboardQuickActions_InventorySubtitle"
                                                    iconName:@"bag.fill"
                                                  badgeText:nil
                                                     enabled:YES
                                                    chevron:YES
                                                     handler:^{
            PPProviderMarketItemsViewController *vc = [[PPProviderMarketItemsViewController alloc] init];
            [weakSelf.navigationController pushViewController:vc animated:YES];
        }]];
    }

    if (canManageDelivery) {
        NSInteger deliveryCount = [self pp_dashboardHeroDeliveryActionCount];
        [items addObject:[PPDashboardQuickActionRailItem itemWithTitleKey:@"DeliveryManagement"
                                                 subtitleKey:@"DashboardQuickActions_DeliverySettingsSubtitle"
                                                    iconName:@"shippingbox.fill"
                                                  badgeText:(deliveryCount > 0 ? [NSString stringWithFormat:@"%ld", (long)deliveryCount] : nil)
                                                     enabled:YES
                                                    chevron:YES
                                                     handler:^{
            [weakSelf pp_markQuickActionKindSeen:PPAdminQuickActionSignalDelivery];
            PPDeliveryDashboardViewController *vc = [[PPDeliveryDashboardViewController alloc] init];
            [weakSelf.navigationController pushViewController:vc animated:YES];
        }]];
    }

    if ([self pp_hasDeliveryCompanyWorkspaceForUser:dashboardUser] && profile.canViewMembers) {
        [items addObject:[PPDashboardQuickActionRailItem itemWithTitleKey:@"DeliveryCompany_Tab_Members"
                                                 subtitleKey:@"DashboardQuickActions_TeamSubtitle"
                                                    iconName:@"person.3.fill"
                                                  badgeText:nil
                                                     enabled:YES
                                                    chevron:YES
                                                     handler:^{
            [weakSelf pp_openDeliveryCompanyMembers];
        }]];
    }

    if (canManageVets) {
        [items addObject:[PPDashboardQuickActionRailItem itemWithTitleKey:@"Vet_Manage_Title"
                                                 subtitleKey:@"Vet_Manage_Subtitle"
                                                    iconName:@"cross.case.fill"
                                                  badgeText:nil
                                                     enabled:YES
                                                    chevron:YES
                                                     handler:^{
            PPVetsListViewController *vc = [[PPVetsListViewController alloc] init];
            [weakSelf.navigationController pushViewController:vc animated:YES];
        }]];
    }

    if (canManagePharmacy) {
        [items addObject:[PPDashboardQuickActionRailItem itemWithTitleKey:@"Pharmacy_Manage_Title"
                                                 subtitleKey:@"Pharmacy_Manage_Subtitle"
                                                    iconName:@"pills.fill"
                                                  badgeText:nil
                                                     enabled:YES
                                                    chevron:YES
                                                     handler:^{
            PPPharmacyMedicinesViewController *vc = [[PPPharmacyMedicinesViewController alloc] init];
            [weakSelf.navigationController pushViewController:vc animated:YES];
        }]];
    }

    if (canManageAdoption) {
        [items addObject:[PPDashboardQuickActionRailItem itemWithTitleKey:@"AdoptPetsTitle"
                                                 subtitleKey:@"AdoptPetsSubtitle"
                                                    iconName:@"heart.fill"
                                                  badgeText:nil
                                                     enabled:YES
                                                    chevron:YES
                                                     handler:^{
            PPAdoptPetsListViewController *vc = [[PPAdoptPetsListViewController alloc] init];
            [weakSelf.navigationController pushViewController:vc animated:YES];
        }]];
    }

    [items addObject:[PPDashboardQuickActionRailItem itemWithTitleKey:@"Notifications"
                                             subtitleKey:@"NoNewNotifications"
                                                iconName:@"bell.badge.fill"
                                              badgeText:nil
                                                 enabled:YES
                                                chevron:YES
                                                 handler:^{
        [PPFunc pp_playTapEffect];
        NotificationsListViewController *controller = [[NotificationsListViewController alloc] init];
        [weakSelf.navigationController pushViewController:controller animated:YES];
    }]];

    if (hasProviderWorkspace) {
        NSString *supportChatsBadge = self.supportChatsUnreadThreadsCount > 0 ? [NSString stringWithFormat:@"%ld", (long)self.supportChatsUnreadThreadsCount] : nil;
        [items addObject:[PPDashboardQuickActionRailItem itemWithTitleKey:@"DashboardQuickActions_SupportTitle"
                                                 subtitleKey:@"DashboardQuickActions_SupportSubtitle"
                                                    iconName:@"message.badge.fill"
                                                  badgeText:supportChatsBadge
                                                     enabled:YES
                                                    chevron:YES
                                                     handler:^{
            [weakSelf pp_openSupportChats];
        }]];
    }

    return items.copy;
}

- (void)pp_startQuickActionSignalObserversForUser:(UserModel *)user {
    NSString *uid = user.uid.length ? user.uid : ([FIRAuth auth].currentUser.uid ?: @"");
    if ([self pp_isDeliveryCompanyOnlyDashboardForUser:user] && self.isDeliveryCompanyMode) {
        NSString *signature = [NSString stringWithFormat:@"%@|company:%@|role:%@",
                               uid ?: @"",
                               self.deliveryCompanyId ?: @"",
                               self.memberRole ?: @""];
        if ([self.quickActionSignalSignature isEqualToString:signature]) {
            return;
        }
        [self pp_stopQuickActionSignalObservers];
        self.quickActionSignalSignature = signature;
        [self pp_refreshQuickActions];
        [self pp_updateDashboardHeroLiveState];
        return;
    }
    BOOL observesDelivery = uid.length > 0 && [self pp_canManageDelivery];
    BOOL observesFulfillment = uid.length > 0 && ([self pp_canManageServices] || [self pp_canManageMarketplace]);
    NSString *signature = [NSString stringWithFormat:@"%@|delivery:%d|fulfillment:%d", uid ?: @"", observesDelivery, observesFulfillment];

    if ([self.quickActionSignalSignature isEqualToString:signature]) {
        return;
    }

    [self pp_stopQuickActionSignalObservers];
    self.quickActionSignalSignature = signature;

    if (!observesDelivery && !observesFulfillment) {
        [self pp_refreshQuickActions];
        [self pp_updateDashboardHeroLiveState];
        return;
    }

    if (observesFulfillment) {
        [self pp_startFulfillmentQuickActionSignalObserverForUID:uid];
        [self pp_startPendingOrdersObserverForUID:uid];
    }
    if (observesDelivery) {
        [self pp_startDeliveryQuickActionSignalObserversForUID:uid];
    }
}

- (void)pp_stopQuickActionSignalObservers {
    [self.quickActionFulfillmentSignalListener remove];
    [self.quickActionDeliveryOpenSignalListener remove];
    [self.quickActionDeliveryAssignedSignalListener remove];
    [self.pendingOrdersListener remove];
    self.quickActionFulfillmentSignalListener = nil;
    self.quickActionDeliveryOpenSignalListener = nil;
    self.quickActionDeliveryAssignedSignalListener = nil;
    self.pendingOrdersListener = nil;
    self.quickActionSignalSignature = nil;

    self.fulfillmentQuickActionSignals = [NSSet set];
    self.deliveryOpenQuickActionSignals = [NSSet set];
    self.deliveryAssignedQuickActionSignals = [NSSet set];
    self.pendingOrders = @[];
    self.hasUnseenDeliveryQuickAction = NO;
    self.hasUnseenFulfillmentQuickAction = NO;
    [self pp_updateDashboardHeroLiveState];
}

- (void)pp_startFulfillmentQuickActionSignalObserverForUID:(NSString *)uid {
    __weak typeof(self) weakSelf = self;
    self.quickActionFulfillmentSignalListener = [[PPFulfillmentManager sharedManager] observeFulfillmentsForOwnerID:uid onChange:^(NSArray<PPFulfillmentModel *> *fulfillments, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error) {
            NSLog(@"[DashboardQuickActions] Fulfillment signal listener error: %@", error.localizedDescription);
            strongSelf.fulfillmentNewRequestsCount = 0;
            [strongSelf pp_applyFulfillmentQuickActionSignals:[NSSet set]];
            return;
        }

        NSMutableSet<NSString *> *signals = [NSMutableSet set];
        NSInteger newRequestsCount = 0;
        for (PPFulfillmentModel *model in fulfillments ?: @[]) {
            NSString *fingerprint = [strongSelf pp_fulfillmentQuickActionSignalFingerprint:model];
            if (fingerprint.length) {
                [signals addObject:fingerprint];
            }
            if ([[model.status lowercaseString] isEqualToString:@"new_request"]) {
                newRequestsCount++;
            }
        }
        strongSelf.fulfillmentNewRequestsCount = newRequestsCount;
        [strongSelf pp_applyFulfillmentQuickActionSignals:signals.copy];
    }];
}

- (void)pp_startPendingOrdersObserverForUID:(NSString *)uid {
    FIRCollectionReference *ordersRef = [[FIRFirestore firestore] collectionWithPath:@"Orders"];
    __weak typeof(self) weakSelf = self;

    FIRQuery *pendingQuery = [[[ordersRef queryWhereField:@"rawStatus" isEqualTo:PPOrderRawStatusPending]
                               queryOrderedByField:@"createdAt" descending:YES]
                              queryLimitedTo:50];

    self.pendingOrdersListener = [pendingQuery addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error) {
            NSLog(@"[DashboardQuickActions] Pending orders listener error: %@", error.localizedDescription);
            strongSelf.pendingOrders = @[];
            [strongSelf pp_refreshQuickActions];
            return;
        }

        NSMutableArray<PPDeliveryOrderModel *> *pendingOrders = [NSMutableArray array];
        for (FIRDocumentSnapshot *document in snapshot.documents) {
            PPDeliveryOrderModel *order = [PPDeliveryOrderModel fromDictionary:document.data withID:document.documentID];
            if (order) {
                [pendingOrders addObject:order];
            }
        }
        strongSelf.pendingOrders = pendingOrders.copy;
        [strongSelf pp_refreshQuickActions];
    }];
}

- (void)pp_startDeliveryQuickActionSignalObserversForUID:(NSString *)uid {
    FIRCollectionReference *ordersRef = [[FIRFirestore firestore] collectionWithPath:@"Orders"];
    __weak typeof(self) weakSelf = self;

    FIRQuery *openQuery = [[[ordersRef queryWhereField:@"deliveryStatus" isEqualTo:PPDeliveryStatusRequested]
                            queryOrderedByField:@"createdAt" descending:YES]
                           queryLimitedTo:50];
    self.quickActionDeliveryOpenSignalListener = [openQuery addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error) {
            NSLog(@"[DashboardQuickActions] Open delivery signal listener error: %@", error.localizedDescription);
            [strongSelf pp_applyDeliveryOpenQuickActionSignals:[NSSet set]];
            return;
        }

        [strongSelf pp_applyDeliveryOpenQuickActionSignals:[strongSelf pp_deliveryQuickActionSignalsFromDocuments:snapshot.documents ?: @[]]];
    }];

    NSArray<NSString *> *assignedStatuses = @[
        PPDeliveryStatusAssigned,
        PPDeliveryStatusAwaitingHandover,
        PPDeliveryStatusPickedUp,
        PPDeliveryStatusInTransit,
        PPDeliveryStatusDelivered,
        PPDeliveryStatusPaymentPending,
        PPDeliveryStatusPaymentConfirmed
    ];
    FIRQuery *assignedQuery = [[[[ordersRef queryWhereField:@"deliveryUserId" isEqualTo:uid]
                                 queryWhereField:@"deliveryStatus" in:assignedStatuses]
                                queryOrderedByField:@"createdAt" descending:YES]
                               queryLimitedTo:50];
    self.quickActionDeliveryAssignedSignalListener = [assignedQuery addSnapshotListener:^(FIRQuerySnapshot * _Nullable snapshot, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error) {
            NSLog(@"[DashboardQuickActions] Assigned delivery signal listener error: %@", error.localizedDescription);
            [strongSelf pp_applyDeliveryAssignedQuickActionSignals:[NSSet set]];
            return;
        }

        [strongSelf pp_applyDeliveryAssignedQuickActionSignals:[strongSelf pp_deliveryQuickActionSignalsFromDocuments:snapshot.documents ?: @[]]];
    }];
}

- (NSString *)pp_fulfillmentQuickActionSignalFingerprint:(PPFulfillmentModel *)model {
    if (![model isKindOfClass:PPFulfillmentModel.class] || model.fulfillmentID.length == 0 || [model isTerminal]) {
        return nil;
    }
    NSString *status = [[PPSafeString(model.status) lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (status.length == 0 || [model availableActions].count == 0) {
        return nil;
    }
    return [NSString stringWithFormat:@"%@:%@", model.fulfillmentID, status];
}

- (NSSet<NSString *> *)pp_deliveryQuickActionSignalsFromDocuments:(NSArray<FIRDocumentSnapshot *> *)documents {
    NSMutableSet<NSString *> *signals = [NSMutableSet set];
    for (FIRDocumentSnapshot *doc in documents) {
        NSDictionary *data = doc.data;
        if (![data isKindOfClass:NSDictionary.class]) {
            continue;
        }
        PPDeliveryOrderModel *order = [PPDeliveryOrderModel fromDictionary:data withID:doc.documentID];
        NSString *fingerprint = [self pp_deliveryQuickActionSignalFingerprint:order];
        if (fingerprint.length) {
            [signals addObject:fingerprint];
        }
    }
    return signals.copy;
}

- (NSString *)pp_deliveryQuickActionSignalFingerprint:(PPDeliveryOrderModel *)order {
    if (![order isKindOfClass:PPDeliveryOrderModel.class] || order.orderId.length == 0 || [order isTerminal]) {
        return nil;
    }

    NSString *status = [[PPSafeString(order.deliveryStatus) lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL hasProviderAction = [order canAcceptDelivery] ||
    [order canConfirmPackageHandover] ||
    [order canMarkInTransit] ||
    [order canMarkDelivered] ||
    [order canCollectCashPayment] ||
    [order canMarkCompleted] ||
    [status isEqualToString:PPDeliveryStatusAssigned];
    if (!hasProviderAction || status.length == 0) {
        return nil;
    }

    NSString *assignee = order.deliveryUserId.length ? order.deliveryUserId : @"open";
    NSString *payment = PPSafeString(order.paymentStatus).lowercaseString ?: @"";
    return [NSString stringWithFormat:@"%@:%@:%@:%@", order.orderId, status, assignee, payment];
}

- (void)pp_applyFulfillmentQuickActionSignals:(NSSet<NSString *> *)signals {
    self.fulfillmentQuickActionSignals = signals ?: [NSSet set];
    [self pp_refreshQuickActionUnseenFlags];
}

- (void)pp_applyDeliveryOpenQuickActionSignals:(NSSet<NSString *> *)signals {
    self.deliveryOpenQuickActionSignals = signals ?: [NSSet set];
    [self pp_refreshQuickActionUnseenFlags];
}

- (void)pp_applyDeliveryAssignedQuickActionSignals:(NSSet<NSString *> *)signals {
    self.deliveryAssignedQuickActionSignals = signals ?: [NSSet set];
    [self pp_refreshQuickActionUnseenFlags];
}

- (void)pp_refreshQuickActionUnseenFlags {
    self.hasUnseenDeliveryQuickAction = [self pp_hasUnseenQuickActionSignals:[self pp_currentDeliveryQuickActionSignals]
                                                                        kind:PPAdminQuickActionSignalDelivery];
    self.hasUnseenFulfillmentQuickAction = [self pp_hasUnseenQuickActionSignals:self.fulfillmentQuickActionSignals ?: [NSSet set]
                                                                           kind:PPAdminQuickActionSignalFulfillment];

    [self pp_refreshQuickActions];
    [self pp_updateDashboardHeroLiveState];
}

- (NSSet<NSString *> *)pp_currentDeliveryQuickActionSignals {
    NSMutableSet<NSString *> *signals = [NSMutableSet set];
    if (self.deliveryOpenQuickActionSignals.count) {
        [signals unionSet:self.deliveryOpenQuickActionSignals];
    }
    if (self.deliveryAssignedQuickActionSignals.count) {
        [signals unionSet:self.deliveryAssignedQuickActionSignals];
    }
    return signals.copy;
}

- (BOOL)pp_hasUnseenQuickActionSignals:(NSSet<NSString *> *)signals kind:(NSString *)kind {
    if (signals.count == 0) {
        return NO;
    }
    NSMutableSet<NSString *> *unseen = [signals mutableCopy];
    [unseen minusSet:[self pp_seenQuickActionSignalsForKind:kind]];
    return unseen.count > 0;
}

- (NSSet<NSString *> *)pp_seenQuickActionSignalsForKind:(NSString *)kind {
    NSArray<NSString *> *stored = [[NSUserDefaults standardUserDefaults] stringArrayForKey:[self pp_quickActionSeenDefaultsKeyForKind:kind]];
    return [NSSet setWithArray:stored ?: @[]];
}

- (void)pp_markQuickActionKindSeen:(NSString *)kind {
    NSSet<NSString *> *signals = [kind isEqualToString:PPAdminQuickActionSignalDelivery]
    ? [self pp_currentDeliveryQuickActionSignals]
    : (self.fulfillmentQuickActionSignals ?: [NSSet set]);
    if (signals.count == 0) {
        return;
    }

    NSArray<NSString *> *sortedSignals = [[signals allObjects] sortedArrayUsingSelector:@selector(compare:)];
    [[NSUserDefaults standardUserDefaults] setObject:sortedSignals forKey:[self pp_quickActionSeenDefaultsKeyForKind:kind]];
    [[NSUserDefaults standardUserDefaults] synchronize];

    if ([kind isEqualToString:PPAdminQuickActionSignalDelivery]) {
        self.hasUnseenDeliveryQuickAction = NO;
    } else if ([kind isEqualToString:PPAdminQuickActionSignalFulfillment]) {
        self.hasUnseenFulfillmentQuickAction = NO;
    }
    [self pp_refreshQuickActions];
    [self pp_updateDashboardHeroLiveState];
}

- (NSString *)pp_quickActionSeenDefaultsKeyForKind:(NSString *)kind {
    NSString *uid = UsrMgr.currentUser.uid.length ? UsrMgr.currentUser.uid : ([FIRAuth auth].currentUser.uid ?: @"unknown");
    return [NSString stringWithFormat:@"PPProDashboardQuickActionSeen.%@.%@", uid, kind ?: @"unknown"];
}

- (NSInteger)pp_dashboardHeroFulfillmentActionCount {
    if (!([self pp_canManageServices] || [self pp_canManageMarketplace])) {
        return 0;
    }
    return (NSInteger)(self.fulfillmentQuickActionSignals ?: [NSSet set]).count;
}

- (NSInteger)pp_pendingOrdersCount {
    if (!([self pp_canManageServices] || [self pp_canManageMarketplace])) {
        return 0;
    }
    if (!self.pendingOrders) {
        return 0;
    }
    NSInteger count = 0;
    for (PPDeliveryOrderModel *order in self.pendingOrders) {
        if ([order.rawStatus isEqualToString:PPOrderRawStatusPending]) {
            count++;
        }
    }
    return count;
}

- (NSInteger)pp_dashboardHeroDeliveryActionCount {
    if (![self pp_canManageDelivery]) {
        return 0;
    }
    return (NSInteger)[self pp_currentDeliveryQuickActionSignals].count;
}

- (void)pp_updateDeliveryCompanyHeroState {
    PPDeliveryCompanyProfile *profile = self.deliveryCompanyContext;
    if (!profile.companyID.length) {
        return;
    }

    NSInteger newCount = [self pp_deliveryCompanyCountForStatuses:@[PPDeliveryCompanyStatusOffered]];
    NSInteger acceptedCount = [self pp_deliveryCompanyCountForStatuses:@[PPDeliveryCompanyStatusAccepted]];
    NSInteger assignedCount = [self pp_deliveryCompanyCountForStatuses:@[PPDeliveryCompanyStatusAssigned]];
    NSInteger inTransitCount = [self pp_deliveryCompanyCountForStatuses:@[
        PPDeliveryCompanyStatusPickedUp,
        PPDeliveryCompanyStatusInTransit
    ]];
    NSInteger deliveredCount = [self pp_deliveryCompanyCountForStatuses:@[PPDeliveryCompanyStatusDelivered]];
    NSInteger activeCount = assignedCount + inTransitCount;
    NSInteger completedTodayCount = [self pp_completedDeliveryCompanyCountToday];

    NSString *commandCount = nil;
    NSString *summary = nil;
    NSString *status = nil;
    NSString *commandTitle = nil;
    NSString *primaryTitle = nil;
    BOOL needsAction = NO;
    BOOL shouldPulse = NO;

    if (profile.isDriver) {
        commandCount = [self pp_deliveryCompanyCountText:activeCount];
        self.heroFulfillmentMetricValueLabel.text = [self pp_deliveryCompanyCountText:assignedCount];
        self.heroDeliveryMetricValueLabel.text = [self pp_deliveryCompanyCountText:inTransitCount];
        self.heroFulfillmentMetricTitleLabel.text = kLang(@"DeliveryCompany_DashboardShell_Metric_Pickups");
        self.heroDeliveryMetricTitleLabel.text = kLang(@"DeliveryCompany_DashboardShell_Metric_InTransit");
        status = kLang(@"DeliveryCompany_DashboardShell_Status_Driver");
        commandTitle = kLang(@"DeliveryCompany_DashboardShell_DriverTitle");
        summary = [NSString stringWithFormat:kLang(@"DeliveryCompany_DashboardShell_DriverSummary_Format"),
                   [self pp_deliveryCompanyCountText:assignedCount],
                   [self pp_deliveryCompanyCountText:inTransitCount],
                   [self pp_deliveryCompanyCountText:completedTodayCount]];
        primaryTitle = kLang(@"DeliveryCompany_DashboardShell_MyAssigned");
        needsAction = activeCount > 0;
        shouldPulse = needsAction;
    } else {
        commandCount = [self pp_deliveryCompanyCountText:newCount];
        self.heroFulfillmentMetricValueLabel.text = [self pp_deliveryCompanyCountText:assignedCount];
        self.heroDeliveryMetricValueLabel.text = [self pp_deliveryCompanyCountText:activeCount];
        self.heroFulfillmentMetricTitleLabel.text = kLang(@"DeliveryCompany_DashboardShell_Metric_Assigned");
        self.heroDeliveryMetricTitleLabel.text = kLang(@"DeliveryCompany_DashboardShell_Metric_Active");
        status = profile.isViewer
            ? kLang(@"DeliveryCompany_DashboardShell_Status_ReadOnly")
            : kLang(@"DeliveryCompany_DashboardShell_Status_Operations");
        commandTitle = profile.isViewer
            ? kLang(@"DeliveryCompany_DashboardShell_ViewerTitle")
            : kLang(@"DeliveryCompany_DashboardShell_OperationsTitle");
        summary = [NSString stringWithFormat:kLang(@"DeliveryCompany_DashboardShell_CompanySummary_Format"),
                   [self pp_deliveryCompanyCountText:acceptedCount],
                   [self pp_deliveryCompanyCountText:deliveredCount]];
        primaryTitle = kLang(@"DeliveryCompany_DashboardShell_OpenCompany");
        needsAction = newCount > 0;
        shouldPulse = needsAction && !profile.isViewer;
    }

    self.heroCommandNumberLabel.text = commandCount ?: @"--";
    self.heroStatusPillLabel.text = status;
    self.adminNameLabel.text = commandTitle;
    self.dashboardSummaryLabel.text = summary;
    self.dashboardSummaryLabel.hidden = NO;
    [self.heroPrimaryActionButton setTitle:primaryTitle forState:UIControlStateNormal];
    self.heroPrimaryActionButton.accessibilityLabel = primaryTitle;

    UIColor *signalColor = [self pp_dashboardHeroSignalColor];
    UIColor *quietColor = [[self pp_dashboardHeroDotColor] colorWithAlphaComponent:0.72];
    self.heroStatusDotView.backgroundColor = shouldPulse ? signalColor : quietColor;
    self.heroStatusDotView.alpha = shouldPulse ? 1.0 : 0.58;
    [self.heroStatusDotView.layer removeAnimationForKey:@"pp.dashboard.hero.status.pulse"];
    if (shouldPulse && !UIAccessibilityIsReduceMotionEnabled()) {
        CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
        pulse.fromValue = @0.42;
        pulse.toValue = @1.0;
        pulse.duration = 1.15;
        pulse.autoreverses = YES;
        pulse.repeatCount = HUGE_VALF;
        pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.heroStatusDotView.layer addAnimation:pulse forKey:@"pp.dashboard.hero.status.pulse"];
    }

    self.headerCard.isAccessibilityElement = NO;
    self.heroCommandNumberLabel.accessibilityLabel =
        [NSString stringWithFormat:kLang(@"DeliveryCompany_DashboardShell_Accessibility_Format"),
                                   commandCount ?: @"--",
                                   status ?: @""];
    self.heroStatusPillLabel.accessibilityLabel = status;
    [self pp_refreshTableHeaderHeight];
}

- (void)pp_updateDashboardHeroLiveState {
    if (!self.heroCommandNumberLabel) {
        return;
    }
    UserModel *dashboardUser = [self pp_activeDashboardUser];
    if ([self pp_isDeliveryCompanyOnlyDashboardForUser:dashboardUser] && self.isDeliveryCompanyMode) {
        [self pp_updateDeliveryCompanyHeroState];
        return;
    }

    NSInteger fulfillmentCount = [self pp_dashboardHeroFulfillmentActionCount];
    NSInteger deliveryCount = [self pp_dashboardHeroDeliveryActionCount];
    NSInteger deliveryCompanyCount = [self pp_dashboardHeroDeliveryCompanyActionCount];
    NSInteger totalCount = fulfillmentCount + deliveryCount + deliveryCompanyCount;
    NSInteger workspaceCount = [self pp_dashboardWorkspaceCountForUser:dashboardUser];
    BOOL needsAction = totalCount > 0;

    self.heroCommandNumberLabel.text = [NSString stringWithFormat:@"%ld", (long)(needsAction ? totalCount : MAX(workspaceCount, 0))];
    self.heroFulfillmentMetricValueLabel.text = [NSString stringWithFormat:@"%ld", (long)workspaceCount];
    self.heroDeliveryMetricValueLabel.text = [NSString stringWithFormat:@"%ld", (long)totalCount];
    self.heroFulfillmentMetricTitleLabel.text = kLang(@"DashboardHero_Metric_Workspaces");
    self.heroDeliveryMetricTitleLabel.text = kLang(@"DashboardHero_Metric_Actions");
    self.heroStatusPillLabel.text = needsAction
        ? kLang(@"DashboardHero_Status_Action")
        : (workspaceCount > 1 ? kLang(@"DashboardHero_Status_MultiWorkspace") : kLang(@"DashboardHero_Status_Live"));
    self.adminNameLabel.text = needsAction
        ? kLang(@"DashboardHero_Command_WorkspacesAction")
        : (workspaceCount > 1 ? kLang(@"DashboardHero_Command_MultiWorkspace") : kLang(@"DashboardHero_Command_AllClear"));

    NSString *summary = nil;
    if (needsAction) {
        NSString *actionSummary = [self pp_dashboardHeroActionSummaryWithFulfillmentCount:fulfillmentCount
                                                                            deliveryCount:deliveryCount
                                                                     deliveryCompanyCount:deliveryCompanyCount];
        summary = [NSString stringWithFormat:kLang(@"DashboardHero_Command_ActionSummary_Format"), actionSummary];
    } else {
        NSArray<NSString *> *workspaceTitles = [self pp_dashboardWorkspaceTitlesForUser:dashboardUser includeDeliveryCompany:YES];
        if (workspaceTitles.count > 0) {
            summary = [NSString stringWithFormat:kLang(@"DashboardHero_Command_WorkspaceSummary_Format"),
                       [workspaceTitles componentsJoinedByString:@" • "]];
        } else {
            summary = kLang(@"DashboardHero_Command_AllClear_Subtitle");
        }
    }
    self.dashboardSummaryLabel.text = summary;
    self.dashboardSummaryLabel.hidden = NO;

    NSString *actionTitle = kLang(@"DashboardHero_CTA_Notifications");
    if (fulfillmentCount > 0 && ([self pp_canManageServices] || [self pp_canManageMarketplace])) {
        actionTitle = kLang(@"DashboardHero_CTA_Fulfillment");
    } else if (deliveryCount > 0 && [self pp_canManageDelivery]) {
        actionTitle = kLang(@"DashboardHero_CTA_Delivery");
    } else if (deliveryCompanyCount > 0 && self.isDeliveryCompanyMode) {
        actionTitle = kLang(@"DashboardHero_CTA_DeliveryCompany");
    } else if ([self pp_canManageMarketplace]) {
        actionTitle = kLang(@"DashboardHero_CTA_Marketplace");
    } else if ([self pp_canManagePharmacy]) {
        actionTitle = kLang(@"DashboardHero_CTA_Pharmacy");
    } else if ([self pp_canManageServices]) {
        actionTitle = kLang(@"DashboardHero_CTA_Services");
    } else if ([self pp_canManageVets]) {
        actionTitle = kLang(@"DashboardHero_CTA_Vets");
    } else if ([self pp_hasDeliveryCompanyWorkspaceForUser:dashboardUser]) {
        actionTitle = kLang(@"DashboardHero_CTA_DeliveryCompany");
    } else if ([self pp_canManageDelivery]) {
        actionTitle = kLang(@"DashboardHero_CTA_Delivery");
    } else if ([self pp_canManageAdoption]) {
        actionTitle = kLang(@"DashboardHero_CTA_Adoption");
    }
    [self.heroPrimaryActionButton setTitle:actionTitle forState:UIControlStateNormal];
    self.heroPrimaryActionButton.accessibilityLabel = actionTitle;

    UIColor *signalColor = [self pp_dashboardHeroSignalColor];
    UIColor *quietColor = [[self pp_dashboardHeroDotColor] colorWithAlphaComponent:0.72];
    self.heroStatusDotView.backgroundColor = needsAction ? signalColor : quietColor;
    self.heroStatusDotView.alpha = needsAction ? 1.0 : 0.58;

    [self.heroStatusDotView.layer removeAnimationForKey:@"pp.dashboard.hero.status.pulse"];
    if (needsAction && !UIAccessibilityIsReduceMotionEnabled()) {
        CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
        pulse.fromValue = @0.42;
        pulse.toValue = @1.0;
        pulse.duration = 1.15;
        pulse.autoreverses = YES;
        pulse.repeatCount = HUGE_VALF;
        pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.heroStatusDotView.layer addAnimation:pulse forKey:@"pp.dashboard.hero.status.pulse"];
    }

    self.headerCard.isAccessibilityElement = NO;
    self.heroCommandNumberLabel.accessibilityLabel =
        [NSString stringWithFormat:kLang(@"DashboardHero_Workspace_Accessibility_Format"), (long)totalCount, (long)workspaceCount];
    self.heroStatusPillLabel.accessibilityLabel = self.heroStatusPillLabel.text;
    [self pp_refreshTableHeaderHeight];
}

- (void)pp_handleDashboardHeroPrimaryAction {
    UserModel *dashboardUser = [self pp_activeDashboardUser];
    if ([self pp_isDeliveryCompanyOnlyDashboardForUser:dashboardUser] && self.isDeliveryCompanyMode) {
        [self pp_openDeliveryCompanyDashboard];
        return;
    }
    [PPFunc pp_playTapEffect];

    NSInteger fulfillmentCount = [self pp_dashboardHeroFulfillmentActionCount];
    NSInteger deliveryCount = [self pp_dashboardHeroDeliveryActionCount];
    NSInteger deliveryCompanyCount = [self pp_dashboardHeroDeliveryCompanyActionCount];
    BOOL canOpenFulfillment = [self pp_canManageServices] || [self pp_canManageMarketplace];
    BOOL canOpenDelivery = [self pp_canManageDelivery];

    if (fulfillmentCount > 0 && canOpenFulfillment) {
        [self pp_markQuickActionKindSeen:PPAdminQuickActionSignalFulfillment];
        PPFulfillmentListViewController *vc = [[PPFulfillmentListViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }

    if (deliveryCount > 0 && canOpenDelivery) {
        [self pp_markQuickActionKindSeen:PPAdminQuickActionSignalDelivery];
        PPDeliveryDashboardViewController *vc = [[PPDeliveryDashboardViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }

    if (deliveryCompanyCount > 0 && self.isDeliveryCompanyMode) {
        [self pp_openDeliveryCompanyDashboard];
        return;
    }

    if ([self pp_canManageMarketplace]) {
        PPProviderMarketItemsViewController *vc = [[PPProviderMarketItemsViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }

    if ([self pp_canManagePharmacy]) {
        PPPharmacyMedicinesViewController *vc = [[PPPharmacyMedicinesViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }

    if ([self pp_canManageServices]) {
        PPServicesListViewController *vc = [[PPServicesListViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }

    if ([self pp_canManageVets]) {
        PPVetsListViewController *vc = [[PPVetsListViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }

    if ([self pp_hasDeliveryCompanyWorkspaceForUser:dashboardUser]) {
        if (self.isDeliveryCompanyMode) {
            [self pp_openDeliveryCompanyDashboard];
        } else {
            PPDeliveryCompanySetupViewController *vc = [[PPDeliveryCompanySetupViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        }
        return;
    }

    if (canOpenDelivery) {
        PPDeliveryDashboardViewController *vc = [[PPDeliveryDashboardViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }

    if ([self pp_canManageAdoption]) {
        PPAdoptPetsListViewController *vc = [[PPAdoptPetsListViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }

    NotificationsListViewController *vc = [[NotificationsListViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (NSString *)pp_accessSummaryForUser:(UserModel *)user {
    if ([self pp_isDeliveryCompanyOnlyDashboardForUser:user] && self.isDeliveryCompanyMode) {
        NSString *companyName = self.deliveryCompanyName.length
            ? self.deliveryCompanyName
            : kLang(@"DeliveryCompany_Title");
        NSString *role = PPDeliveryCompanyRoleDisplayName(self.memberRole);
        NSString *access = self.deliveryCompanyContext.isDriver
            ? kLang(@"DeliveryCompany_DashboardShell_DriverAccess")
            : (self.deliveryCompanyContext.isViewer
               ? kLang(@"DeliveryCompany_DashboardShell_ViewerAccess")
               : kLang(@"DeliveryCompany_DashboardShell_OperationsAccess"));
        return [NSString stringWithFormat:kLang(@"DeliveryCompany_DashboardShell_Access_Format"),
                                          companyName,
                                          role,
                                          access];
    }
    if (!user) return @"";
    //return kLang(@"AdminDashboard_FullControl");
    NSMutableArray<NSString *> *parts = [[self pp_dashboardWorkspaceTitlesForUser:user includeDeliveryCompany:YES] mutableCopy];
    [parts addObject:kLang(@"Notifications")];
    [parts addObject:kLang(@"Settings")];
    return [parts componentsJoinedByString:@" • "];
}

- (XLFormRowDescriptor *)pp_rowDescriptorForIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) return nil;
    if (indexPath.section >= self.form.formSections.count) return nil;
    XLFormSectionDescriptor *section = self.form.formSections[indexPath.section];
    if (indexPath.row >= section.formRows.count) return nil;
    return section.formRows[indexPath.row];
}

- (NSString *)pp_formSectionTitleAtIndex:(NSInteger)section {
    if (section < 0 || section >= self.form.formSections.count) return @"";
    XLFormSectionDescriptor *formSection = self.form.formSections[section];
    return formSection.title ?: @"";
}

- (void)pp_playDashboardEntranceIfNeeded {
    [self pp_startHeaderAccentMotionIfNeeded];

    if (self.didPlayDashboardEntrance || self.view.window == nil) {
        return;
    }

    self.didPlayDashboardEntrance = YES;

    // Fade in ambient background glows
    NSArray<UIView *> *glows = @[self.bgAmbientGlow1 ?: [UIView new], self.bgAmbientGlow2 ?: [UIView new], self.bgAmbientGlow3 ?: [UIView new]];
    for (UIView *glow in glows) {
        if (!glow.superview) continue;
        glow.alpha = 0.0;
        glow.transform = CGAffineTransformMakeScale(0.8, 0.8);
    }
    [UIView animateWithDuration:1.2 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        for (UIView *glow in glows) {
            if (!glow.superview) continue;
            glow.alpha = 1.0;
            glow.transform = CGAffineTransformIdentity;
        }
    } completion:nil];

NSArray<UIView *> *headerViews = @[self.headerCard ?: [UIView new], self.quickActionsView ?: [UIView new], self.subscriptionFooterCard ?: [UIView new]];
    [headerViews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, __unused BOOL *stop) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0, 18);
        [UIView animateWithDuration:0.62
                            delay:0.06 * idx
             usingSpringWithDamping:0.90
              initialSpringVelocity:0.35
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self quickActionsRailView] ? [[self quickActionsRailView] animateEntrance] : nil;
        [self pp_animateVisibleCellsModern];
    });
}

- (void)pp_startHeaderAccentMotionIfNeeded {
    [self.heroSurfaceView startMotion];
    if (self.didStartHeaderAccentMotion) return;

    if (UIAccessibilityIsReduceMotionEnabled()) {
          self.heroLiveLineView.alpha = 1.0;
        self.heroAvatarPulseView.alpha = 1.0;
        self.heroAvatarContainerView.transform = CGAffineTransformIdentity;


        for (UIView *view in self.heroOrbitRingViews) {
            view.alpha = 0.92;
            view.transform = CGAffineTransformIdentity;
        }

        return;
    }

    self.didStartHeaderAccentMotion = YES;

    [self.heroOrbitRingViews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, __unused BOOL *stop) {
        if (!view.superview) return;

        CABasicAnimation *orbitRotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        orbitRotation.fromValue = @0.0;
        orbitRotation.toValue = @((idx == 0) ? (M_PI * 2.0) : -(M_PI * 2.0));
        orbitRotation.duration = (idx == 0) ? 5.8 : 7.2;
        orbitRotation.repeatCount = HUGE_VALF;
        orbitRotation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
        [view.layer addAnimation:orbitRotation forKey:@"pp.dashboard.hero.orbit.rotation"];

        CABasicAnimation *orbitOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
        orbitOpacity.toValue = @((idx == 0) ? 0.92 : 0.38);
        orbitOpacity.duration = (idx == 0) ? 2.6 : 3.4;
        orbitOpacity.autoreverses = YES;
        orbitOpacity.repeatCount = HUGE_VALF;
        orbitOpacity.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [view.layer addAnimation:orbitOpacity forKey:@"pp.dashboard.hero.orbit.opacity"];
    }];

    if (self.heroLiveLineView.superview) {
        CABasicAnimation *lineOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
        lineOpacity.toValue = @0.82;
        lineOpacity.duration = 2.6;
        lineOpacity.autoreverses = YES;
        lineOpacity.repeatCount = HUGE_VALF;
        lineOpacity.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.heroLiveLineView.layer addAnimation:lineOpacity forKey:@"pp.dashboard.hero.line.opacity"];

        CABasicAnimation *lineScale = [CABasicAnimation animationWithKeyPath:@"transform.scale.x"];
        lineScale.toValue = @0.52;
        lineScale.duration = 3.0;
        lineScale.autoreverses = YES;
        lineScale.repeatCount = HUGE_VALF;
        lineScale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.heroLiveLineView.layer addAnimation:lineScale forKey:@"pp.dashboard.hero.line.scale"];
    }

    if (self.heroAvatarPulseView.superview) {
        CABasicAnimation *pulseScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        pulseScale.toValue = @1.11;
        pulseScale.duration = 3.2;
        pulseScale.autoreverses = YES;
        pulseScale.repeatCount = HUGE_VALF;
        pulseScale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.heroAvatarPulseView.layer addAnimation:pulseScale forKey:@"pp.dashboard.hero.avatar.scale"];

        CABasicAnimation *pulseOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
        pulseOpacity.toValue = @0.78;
        pulseOpacity.duration = 3.2;
        pulseOpacity.autoreverses = YES;
        pulseOpacity.repeatCount = HUGE_VALF;
        pulseOpacity.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.heroAvatarPulseView.layer addAnimation:pulseOpacity forKey:@"pp.dashboard.hero.avatar.opacity"];
    }

    if (self.heroAvatarContainerView.superview) {
        CABasicAnimation *containerScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        containerScale.toValue = @1.045;
        containerScale.duration = 3.4;
        containerScale.autoreverses = YES;
        containerScale.repeatCount = HUGE_VALF;
        containerScale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.heroAvatarContainerView.layer addAnimation:containerScale forKey:@"pp.dashboard.hero.avatar.container.scale"];
    }

}

- (void)pp_stopHeaderAccentMotion {
    [self.heroSurfaceView stopMotion];
     [self.heroLiveLineView.layer removeAnimationForKey:@"pp.dashboard.hero.line.opacity"];
    [self.heroLiveLineView.layer removeAnimationForKey:@"pp.dashboard.hero.line.scale"];
    [self.heroAvatarPulseView.layer removeAnimationForKey:@"pp.dashboard.hero.avatar.scale"];
    [self.heroAvatarPulseView.layer removeAnimationForKey:@"pp.dashboard.hero.avatar.opacity"];
    [self.heroAvatarContainerView.layer removeAnimationForKey:@"pp.dashboard.hero.avatar.container.scale"];
    [self.heroStatusDotView.layer removeAnimationForKey:@"pp.dashboard.hero.status.pulse"];
    for (UIView *view in self.heroOrbitRingViews) {
        [view.layer removeAnimationForKey:@"pp.dashboard.hero.orbit.rotation"];
        [view.layer removeAnimationForKey:@"pp.dashboard.hero.orbit.opacity"];
    }

    self.didStartHeaderAccentMotion = NO;
}


#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self pp_configureDashboardAppearance];
    [self pp_refreshDeliveryCompanyDashboardSummary];
    [self pp_refreshDeliveryCompanyMembership];

    NSString *currentUID = [FIRAuth auth].currentUser.uid;
    UserModel *curUser = UsrMgr.currentUser ?: (currentUID.length ? [UsrMgr p_readUserFromDisk:currentUID] : nil);
    if (curUser) {
        UsrMgr.currentUser = curUser;
        PPLOG(@"[FUM] viewDidLoad cached dashboard user: uid=%@ email=%@ token=%@ name=%@",
              curUser.uid, curUser.UserEmail, curUser.PPProTokenID, curUser.displayName);
        [self setupHeaderUIWithUser:curUser];
        [self pp_rebuildDashboardFormPreservingOffset:NO];
        [self pp_syncCachedAdminNotificationTokenIfNeeded];
        [self pp_startProviderSubscriptionObserver];
        [self pp_startDashboardAccessObserversForUser:curUser];
        [self pp_startInboxUnreadObserverForUser:curUser];
        [self pp_startSupportChatsUnreadObserverForUser:curUser];
        self.didCompleteInitialDashboardLoad = YES;
    } else {
        __weak typeof(self) weakSelf = self;
        [FUM reloadCurrentUserWithCompletion:^(UserModel * _Nullable user, NSError * _Nullable error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (error || !user) {
                [strongSelf showLogin];
                return;
            }

            PPLOG(@"[FUM] viewDidLoad reloaded dashboard user: uid=%@ email=%@ token=%@ name=%@",
                  user.uid, user.UserEmail, user.PPProTokenID, user.displayName);

            UsrMgr.currentUser = user;
            [UsrMgr p_cacheUser:user];
            if (currentUID.length) {
                [UsrMgr p_writeUserToDisk:user forUID:currentUID];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf setupHeaderUIWithUser:user];
                [strongSelf pp_rebuildDashboardFormPreservingOffset:NO];
                [strongSelf pp_syncCachedAdminNotificationTokenIfNeeded];
                [strongSelf pp_startProviderSubscriptionObserver];
                [strongSelf pp_startDashboardAccessObserversForUser:user];
                [strongSelf pp_startInboxUnreadObserverForUser:user];
                [strongSelf pp_startSupportChatsUnreadObserverForUser:user];
                strongSelf.didCompleteInitialDashboardLoad = YES;
            });
        }];
        return;
    }
}

- (void)pp_syncCachedAdminNotificationTokenIfNeeded {
    UserModel *currentUser = UsrMgr.currentUser;
    if (!currentUser) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    void (^syncToken)(NSString *) = ^(NSString *token) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        NSString *safeToken = [token isKindOfClass:NSString.class] ? [token stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
        if (safeToken.length == 0) {
            return;
        }

        if ([currentUser.PPProTokenID isEqualToString:safeToken]) {
            return;
        }

        currentUser.PPProTokenID = safeToken;
        [currentUser SYNC:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"[FIRMessaging] Failed syncing cached admin dashboard token: %@", error.localizedDescription);
            } else {
                NSLog(@"[FIRMessaging] Cached admin dashboard token synced for %@", currentUser.uid);
            }
        }];
    };

    NSString *cachedToken = PPNotifications.deviceToken;
    if ([cachedToken isKindOfClass:NSString.class] && cachedToken.length > 0) {
        syncToken(cachedToken);
        return;
    }

    [PPNotifications getDeviceTokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[FIRMessaging] Unable to fetch admin token on dashboard load: %@", error.localizedDescription);
            return;
        }
        syncToken(token);
    }];
}

#pragma mark - UI Header
- (void)setupHeaderUIWithUser:(UserModel *)curUser {
    if (!curUser) return;

    PPLOG(@"[FUM] setupHeaderUIWithUser: uid=%@ email=%@ token=%@ name=%@",
          curUser.uid, curUser.UserEmail, curUser.PPProTokenID, curUser.displayName);

    [self pp_buildDashboardHeaderIfNeeded];
    [self pp_refreshQuickActions];
    [self updateHeaderWithUser:curUser];
    [self pp_refreshTableHeaderHeight];
}

- (void)didTapAddProfilePhoto {
    [PPFunc pp_playTapEffect];
    if (![FIRAuth auth].currentUser) {
        NSLog(@"⚠️ [ProfilePhoto] User not logged in");
        [PPToast toast:kLang(@"Please login first")];
        return;
    }

    NSLog(@"📸 [ProfilePhoto] System photo picker opened");

    if (@available(iOS 14.0, *)) {
        // iOS 14+: PHPicker (no permission prompt, handles iCloud automatically)
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
        config.selectionLimit = 1;
        config.filter = [PHPickerFilter imagesFilter];
        // Prefer the current/full rep; iCloud download handled by the system
        config.preferredAssetRepresentationMode = PHPickerConfigurationAssetRepresentationModeCurrent;

        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    } else {
        // iOS 13 and earlier: UIImagePickerController
        if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
            [PPToast toast:kLang(@"Photo library unavailable")];
            return;
        }
        UIImagePickerController *picker = [UIImagePickerController new];
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        picker.mediaTypes = @[(NSString *)kUTTypeImage];
        picker.delegate = self;
        picker.allowsEditing = NO;
        [self presentViewController:picker animated:YES completion:nil];
    }
}

#pragma mark - PHPicker (iOS 14+)

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14.0)){
    [picker dismissViewControllerAnimated:YES completion:nil];

    if (results.count == 0) {
        NSLog(@"🚫 [ProfilePhoto] Photo picker canceled / no selection");
        return;
    }

    PHPickerResult *result = results.firstObject;
    NSItemProvider *provider = result.itemProvider;

    if ([provider canLoadObjectOfClass:[UIImage class]]) {
        // HUD – ring
        self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
        self.hud.indicatorView = [[JGProgressHUDRingIndicatorView alloc] init];
        self.hud.textLabel.text = kLang(@"Preparing…");
        [self.hud showInView:self.view];
        NSLog(@"⏳ [ProfilePhoto] HUD displayed (Preparing…)");

        __weak typeof(self) weakSelf = self;
        [provider loadObjectOfClass:[UIImage class] completionHandler:^(__kindof id<NSItemProviderReading>  _Nullable object, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;

                if (error) {
                    NSLog(@"❌ [ProfilePhoto] ItemProvider load error: %@", error);
                    [self.hud dismiss];
                    [PPToast toast:kLang(@"Image load failed")];
                    return;
                }

                UIImage *image = (UIImage *)object;
                if (!image) {
                    NSLog(@"❌ [ProfilePhoto] ItemProvider returned nil image");
                    [self.hud dismiss];
                    [PPToast toast:kLang(@"Image load failed")];
                    return;
                }

                [PPFunc pp_presentCircularCropperWithImage:image fromController:self];



            });
        }];
    } else if ([provider hasItemConformingToTypeIdentifier:@"public.jpeg"]) {
        // Fallback path: load data rep if UIImage class isn’t directly available
        self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
        self.hud.indicatorView = [[JGProgressHUDRingIndicatorView alloc] init];
        self.hud.textLabel.text = kLang(@"Preparing…");
        [self.hud showInView:self.view];

        __weak typeof(self) weakSelf = self;
        [provider loadDataRepresentationForTypeIdentifier:@"public.jpeg"
                                        completionHandler:^(NSData * _Nullable data, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;

                if (error || data.length == 0) {
                    NSLog(@"❌ [ProfilePhoto] Data rep load failed: %@", error);
                    [self.hud dismiss];
                    [PPToast toast:kLang(@"Image load failed")];
                    return;
                }
                UIImage *img = [UIImage imageWithData:data];
                if (!img) {
                    NSLog(@"❌ [ProfilePhoto] Failed to decode JPEG");
                    [self.hud dismiss];
                    [PPToast toast:kLang(@"Image load failed")];
                    return;
                }

                NSLog(@"✅ [ProfilePhoto] Image ready for upload");
                [PPFunc pp_presentCircularCropperWithImage:img fromController:self];

            });
        }];
    } else {
        NSLog(@"⚠️ [ProfilePhoto] Provider cannot load UIImage or public.jpeg");
        [PPToast toast:kLang(@"Unsupported image type")];
    }
}

-(void)cropViewController:(TOCropViewController *)cropViewController didCropToCircularImage:(UIImage *)image withRect:(CGRect)cropRect angle:(NSInteger)angle
{
    [cropViewController dismissViewControllerAnimated:YES completion:^{

        [self startUploadOfImage:image];
    }];
}

#pragma mark - UIImagePickerController (iOS 13-)

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];

    UIImage *image = info[UIImagePickerControllerOriginalImage] ?: info[UIImagePickerControllerEditedImage];
    if (!image) {
        NSLog(@"❌ [ProfilePhoto] No image from UIImagePickerController");
        [PPToast toast:kLang(@"Image load failed")];
        return;
    }
    [PPHUD dismiss];
    [PPHUD showRingIn:self.view title:kLang(@"Preparing…")];
    NSLog(@"⏳ [ProfilePhoto] HUD displayed (Preparing…)");

    NSLog(@"✅ [ProfilePhoto] Image ready for upload (legacy picker)");
    [PPFunc pp_presentCircularCropperWithImage:image fromController:self];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSLog(@"🚫 [ProfilePhoto] Photo picker canceled");
}



// Upload helper using FUManager progress
- (void)startUploadOfImage:(UIImage *)img {
    NSLog(@"📤 [Upload] Starting upload process…");
    [PPHUD dismiss];
    self.hud.textLabel.text = kLang(@"Uploading…");
    self.hud.detailTextLabel.text = nil;
    JGProgressHUDRingIndicatorView *ring = (JGProgressHUDRingIndicatorView *)self.hud.indicatorView;
    ring.progress = 0.0;

    __weak typeof(self) weakSelf = self;
    [[FUManager shared] updatePhotoImage:img
                         maxDimension_px:800
                                maxBytes:350*1024
                                progress:^(double fraction) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self.hud) return;

        ring.progress = fraction;
        self.hud.textLabel.text = [NSString stringWithFormat:@"%.0f%%", fraction * 100.0];

        NSLog(@"📊 [Upload] Progress: %.1f%%", fraction * 100.0);
    }
                              completion:^(NSURL * _Nullable url, NSError * _Nullable error)
     {
        __strong typeof(weakSelf) self = weakSelf;

        if (error || !url) {
            NSLog(@"❌ [Upload] Failed with error: %@", error.localizedDescription);

            self.hud.indicatorView = [[JGProgressHUDErrorIndicatorView alloc] init];
            self.hud.textLabel.text = kLang(@"Failed");
            self.hud.detailTextLabel.text = error.localizedDescription ?: kLang(@"Upload failed");
            [self.hud dismissAfterDelay:1.4];
            self.hud = nil;
            return;
        }

        NSLog(@"✅ [Upload] Success! File URL: %@", url.absoluteString);

        // Success -> swap indicator, then set the avatar
        self.hud.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];
        self.hud.textLabel.text = kLang(@"Done");
        self.hud.detailTextLabel.text = nil;
        [self.hud dismissAfterDelay:0.9];
        self.hud = nil;


        UsrMgr.currentUser.UserImageUrl = url;
        UsrMgr.currentUser.photoURL = url.absoluteString;
        [UsrMgr p_cacheUser:UsrMgr.currentUser];

        [self updateHeaderWithUser:UsrMgr.currentUser];
        [PPToast toast:kLang(@"Saved") style:PPToastStyleSuccess haptic:YES duration:1.6];
    }];
}





- (void)pp_setAddPhotoBadgeVisible:(BOOL)visible {
    if (!self.addPhotoButton) return;
    self.addPhotoButton.hidden = NO;
    [UIView animateWithDuration:0.20
                     animations:^{
        self.addPhotoButton.alpha = visible ? 1.0 : 0.0;
        self.addPhotoButton.transform = visible ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.88, 0.88);
    } completion:^(__unused BOOL finished) {
        self.addPhotoButton.hidden = !visible;
    }];
}

- (NSData *)pp_avatarPNGFromImage:(UIImage *)image maxSide:(CGFloat)side {
    if (!image) return nil;

    CGSize s = image.size;
    CGFloat maxDim = MAX(s.width, s.height);
    UIImage *outImg = image;

    if (maxDim > side) {
        CGFloat scale = side / maxDim;
        CGSize newSize = CGSizeMake(floor(s.width * scale), floor(s.height * scale));

        UIGraphicsBeginImageContextWithOptions(newSize, NO, 1.0);
        [image drawInRect:(CGRect){.origin=CGPointZero, .size=newSize}];
        outImg = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    NSData *data = UIImagePNGRepresentation(outImg);
    return data;
}

// Called whenever data changes (can be reused)
- (void)updateHeaderWithUser:(UserModel *)u {
    if (!u) return;
    PPLOG(@"updateHeaderWithUser: uid=%@ role(raw)=%ld -> localized=%@",
          u.uid, (long)u.role, [PPRolePermission localizedRoleName:u.role]);
    PPLOG(@"updateHeaderWithUser: %@ / %@", u.uid, u.displayName);

    [self pp_applyDashboardNameForUser:u];
    self.dashboardAccessLabel.text = [self pp_accessSummaryForUser:u];
    [self pp_startQuickActionSignalObserversForUser:u];
    [self pp_updateDashboardHeroLiveState];
    [self pp_refreshQuickActions];

    NSURL *url = nil;
    if ([u.UserImageUrl isKindOfClass:NSURL.class]) {
        url = (NSURL *)u.UserImageUrl;
    } else if ([u.UserImageUrl isKindOfClass:NSString.class]) {
        url = [NSURL URLWithString:(NSString *)u.UserImageUrl];
    }

    if (!url.absoluteString.length && [FIRAuth auth].currentUser.photoURL.absoluteString.length) {
        url = [FIRAuth auth].currentUser.photoURL;
    }

    [self pp_applyAvatarURL:url];
    [self pp_refreshTableHeaderHeight];
}

- (void)didTapEditNameButton {
    [PPFunc pp_playTapEffect];


    [PPAlertHelper showTextPromptIn:self
                              title:kLang(@"EditName")
                           subtitle:kLang(@"EnterYourName")
                        placeholder:UsrMgr.currentUser.displayName
                        initialText:UsrMgr.currentUser.displayName
                        confirmText:nil
                         cancelText:nil
                        secureEntry:NO
                       keyboardType:UIKeyboardTypeAlphabet
                         completion:^(NSString * _Nullable text) {

        [PPHUD showRingIn:self.view title:kLang(@"Updating") subtitle:kLang(@"Please wait")];
        if (text.length == 0) { [PPHUD dismiss]; return; }

        UserModel *usr = UsrMgr.currentUser;
        usr.displayName = text;
        [UsrMgr p_cacheUser:usr];
        [usr SYNC:^(NSError * _Nullable error) {

            dispatch_async(dispatch_get_main_queue(), ^{
                // Your code to execute on main thread
                [UIView animateWithDuration:0.4 animations:^{
                    [self updateHeaderWithUser:UsrMgr.currentUser];
                } completion:^(BOOL finished) {

                    [PPHUD dismiss];
                    [PPHUD showSuccess:kLang(@"Saved")];

                }];

            });
        }];
    }];
}


- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self pp_refreshTableHeaderHeight];
    [self pp_refreshSubscriptionFooterHeight];
    [self pp_applyDashboardHeroShadow];
}

#pragma mark - UI Header

- (void)pp_applyAvatarURL:(NSURL * _Nullable)url {
    UIImage *placeholder = [UIImage systemImageNamed:@"person.crop.circle.fill"];
    self.avatarIMV.image = placeholder;
    self.avatarIMV.tintColor = SeconderyTextClr ?: UIColor.secondaryLabelColor;

    if (!url.absoluteString.length) {
        self.avatarIMV.contentMode = UIViewContentModeCenter;
        [self pp_setAddPhotoBadgeVisible:YES];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self.avatarIMV setImageFromUrl:url.absoluteString
                   placeholderImage:@"person.crop.circle.fill"
                         completion:^(UIImage *image) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        BOOL hasImage = (image != nil);
        strongSelf.avatarIMV.contentMode = hasImage ? UIViewContentModeScaleAspectFill : UIViewContentModeCenter;
        [strongSelf pp_setAddPhotoBadgeVisible:!hasImage];
        [strongSelf pp_refreshTableHeaderHeight];
    }];
}

- (void)pp_refreshTableHeaderHeight {
    if (!self.headerRoot) return;

    CGFloat targetWidth = MAX(self.tableView.bounds.size.width, self.view.bounds.size.width);
    CGFloat currentMinOffsetY = -self.tableView.adjustedContentInset.top;
    CGFloat currentOffsetY = self.tableView.contentOffset.y;
    BOOL wasPinnedToTop = currentOffsetY <= (currentMinOffsetY + 1.0);
    CGRect frame = self.headerRoot.frame;
    BOOL didChangeWidth = fabs(frame.size.width - targetWidth) > 0.5;
    frame.size.width = targetWidth;
    self.headerRoot.frame = frame;

    [self.headerRoot setNeedsLayout];
    [self.headerRoot layoutIfNeeded];

    CGSize targetSize = CGSizeMake(targetWidth, UILayoutFittingCompressedSize.height);
    CGFloat height = [self.headerRoot systemLayoutSizeFittingSize:targetSize
                                    withHorizontalFittingPriority:UILayoutPriorityRequired
                                          verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
    height = MAX(1.0, height);

    if (didChangeWidth || fabs(self.headerRoot.frame.size.height - height) > 0.5) {
        frame.size.height = height;
        self.headerRoot.frame = frame;
        self.tableView.tableHeaderView = self.headerRoot;
        if (wasPinnedToTop) {
            [self.tableView setContentOffset:CGPointMake(0, -self.tableView.adjustedContentInset.top) animated:NO];
        }
    }

    self.avatarIMV.layer.cornerRadius = self.avatarIMV.bounds.size.height / 2.0;
    self.avatarIMV.clipsToBounds = YES;
}

#pragma mark - Table reload animation

- (void)reloadTableAnimated:(BOOL)animated {
    [self.tableView reloadData];
    [self.tableView layoutIfNeeded];

    if (animated) {
        [self pp_animateVisibleCellsModern];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return [self pp_formSectionTitleAtIndex:section].length > 0 ? 46.0 : 14.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return section == self.form.formSections.count - 1 ? 12.0 : 8.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *title = [self pp_formSectionTitleAtIndex:section];
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = UIColor.clearColor;
    container.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;

    if (title.length == 0) {
        return container;
    }

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [Styling fontBold:14];
    label.textColor = SeconderyTextClr ?: UIColor.secondaryLabelColor;
    label.text = title;
    label.textAlignment = Language.alignmentForCurrentLanguage;
    [container addSubview:label];

    UIView *dotView = [[UIView alloc] init];
    dotView.translatesAutoresizingMaskIntoConstraints = NO;
    dotView.backgroundColor = [AppPrimaryClr ?: UIColor.systemTealColor colorWithAlphaComponent:0.20];
    dotView.layer.cornerRadius = 4.0;
    [container addSubview:dotView];

    UIView *line = [[UIView alloc] init];
    line.translatesAutoresizingMaskIntoConstraints = NO;
    line.backgroundColor = [(AppPrimaryClr ?: UIColor.separatorColor) colorWithAlphaComponent:0.12];
    line.layer.cornerRadius = 1.0;
    [container addSubview:line];

    BOOL isRTL = Language.isRTL;
    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray arrayWithArray:@[
        [dotView.centerYAnchor constraintEqualToAnchor:container.centerYAnchor constant:4.0],
        [dotView.widthAnchor constraintEqualToConstant:8.0],
        [dotView.heightAnchor constraintEqualToConstant:8.0],
        [label.centerYAnchor constraintEqualToAnchor:dotView.centerYAnchor],
        [line.centerYAnchor constraintEqualToAnchor:dotView.centerYAnchor],
        [line.heightAnchor constraintEqualToConstant:1.0],
    ]];

    if (isRTL) {
        [constraints addObjectsFromArray:@[
            [dotView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-(PPAdminDashboardHorizontalInset + 4.0)],
            [label.trailingAnchor constraintEqualToAnchor:dotView.leadingAnchor constant:-10.0],
            [line.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:PPAdminDashboardHorizontalInset + 4.0],
            [line.trailingAnchor constraintEqualToAnchor:label.leadingAnchor constant:-12.0],
        ]];
    } else {
        [constraints addObjectsFromArray:@[
            [dotView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:PPAdminDashboardHorizontalInset + 4.0],
            [label.leadingAnchor constraintEqualToAnchor:dotView.trailingAnchor constant:10.0],
            [line.leadingAnchor constraintEqualToAnchor:label.trailingAnchor constant:12.0],
            [line.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-(PPAdminDashboardHorizontalInset + 4.0)],
        ]];
    }

    [NSLayoutConstraint activateConstraints:constraints];

    return container;
}

#pragma mark - TableView Background Section Style
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {

    /* ── XLAdminCell cards handle their own rendering ── */
    if ([cell isKindOfClass:[XLAdminCell class]]) {
        cell.backgroundColor = UIColor.clearColor;
        cell.contentView.backgroundColor = UIColor.clearColor;
        cell.preservesSuperviewLayoutMargins = NO;
        cell.layoutMargins = UIEdgeInsetsMake(0, 12, 0, 12);
        cell.separatorInset = UIEdgeInsetsMake(0, 12, 0, 12);
        return;
    }

    /* ── Standard rows (switch, etc.) → card-style surface ── */
    UIColor *accent  = AppPrimaryClr ?: UIColor.systemTealColor;
    UIColor *surface = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    BOOL isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;

    cell.backgroundColor = UIColor.clearColor;
    cell.contentView.backgroundColor = UIColor.clearColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.font = [Styling fontMedium:15];
    cell.textLabel.textColor = PrimaryTextClr ?: UIColor.labelColor;
    cell.preservesSuperviewLayoutMargins = NO;
    cell.layoutMargins = UIEdgeInsetsMake(0, 12, 0, 12);
    cell.separatorInset = UIEdgeInsetsMake(0, 12, 0, 12);

    /* Reuse or create a background card view (tag 8801) */
    UIView *bg = [cell.contentView viewWithTag:8801];
    if (!bg) {
        bg = [[UIView alloc] init];
        bg.tag = 8801;
        bg.translatesAutoresizingMaskIntoConstraints = NO;
        bg.layer.cornerRadius  = 22.0;
        bg.layer.cornerCurve   = kCACornerCurveContinuous;
        bg.userInteractionEnabled = NO;
        [cell.contentView insertSubview:bg atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [bg.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:4],
            [bg.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-4],
            [bg.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:2],
            [bg.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-2],
        ]];
    }
    bg.backgroundColor = surface;
    bg.layer.borderWidth  = 1.0 / UIScreen.mainScreen.scale;
    bg.layer.borderColor  = [accent colorWithAlphaComponent:isDark ? 0.12 : 0.08].CGColor;
    bg.layer.shadowColor  = UIColor.clearColor.CGColor;
    bg.layer.shadowOpacity = isDark ? 0.10 : 0.04;
    bg.layer.shadowRadius  = 8.0;
    bg.layer.shadowOffset  = CGSizeMake(0, 3);
    bg.clipsToBounds = NO;
    cell.clipsToBounds = NO;
    cell.contentView.clipsToBounds = NO;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    XLFormRowDescriptor *row = [self pp_rowDescriptorForIndexPath:indexPath];
    return [row.rowType isEqualToString:@"XLAdminCell"] ? 78.0 : 78.0;
}


#pragma mark - Language Actions

- (void)didTapLanguage {
    [PPFunc pp_playTapEffect];

    NSInteger newLangVal = ([Language languageVal] == 0) ? 1 : 0;
    NSString *newLang = LanguageCode[newLangVal];
    UIImage *warnIcon = [UIImage systemImageNamed:@"globe.central.south.asia.fill"]; // AlertIcon
    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showConfirmationIn:self
                                title:kLang(@"Confirm_LanguageChange_Title")
                             subtitle:kLang(@"Confirm_LanguageChange_Msg")
                          placeholder:nil
                        confirmButton:kLang(@"Confirm")
                         cancelButton:kLang(@"Cancel")
                                 icon:warnIcon
                         confirmBlock:^{
        [Language userSelectedLanguage:newLang];
        [PPAlertHelper showSuccessIn:weakSelf
                               title:kLang(@"Success")
                            subtitle:kLang(@"Language changed successfully")];
    }
                          cancelBlock:nil];
}
// Minimal login presentation that uses your AdminLoginViewController
- (void)showLogin {
    [PPFunc pp_playTapEffect];
    AdminLoginViewController *vc = [[AdminLoginViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)dealloc {
    [self pp_stopHeaderAccentMotion];
    [self pp_stopQuickActionSignalObservers];
    [self pp_stopProviderSubscriptionObserver];
    [self pp_stopInboxUnreadObserver];
    [self pp_stopSupportChatsUnreadObserver];
    if (self.reg) {
        [self.reg remove];
        self.reg = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_refreshDeliveryCompanyDashboardSummary];
    [self pp_refreshDeliveryCompanyMembership];

    if (UsrMgr.currentUser) {
        [self updateHeaderWithUser:UsrMgr.currentUser];
    }
    if (self.didCompleteInitialDashboardLoad) {
        [self pp_rebuildDashboardFormPreservingOffset:YES];
    }
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"AdminDashboard") showBack:NO];
    [self pp_navBarSetRightIcon:@"gearshape.fill" key:kPPKeyBaseBack target:self action:@selector(pp_openProfileSettings) tap:^{}];
    [self pp_navBarSetLeftIcon:@"power.circle.fill" key:kPPKeyBaseButton target:self action:@selector(didTapAuthButton) tap:^{}];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self pp_stopHeaderAccentMotion];
}

- (void)didTapBiometric {
    DLog(@"[Biometric] Dashboard biometric entry tapped while service is disabled");
    [PPToast toast:kLang(@"Biometric authentication is disabled") style:PPToastStyleInfo haptic:NO duration:2.0];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self pp_syncCachedAdminNotificationTokenIfNeeded];
    [self pp_playDashboardEntranceIfNeeded];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self pp_updateAmbientGlowsForStyle];
        [self pp_refreshDashboardHeroMaterials];
        self.subscriptionFooterCard.backgroundColor = [self pp_subscriptionFooterSurfaceColor];
        [self pp_renderSubscriptionFooter];
        [self.tableView reloadData];
    }
}

- (void)didTapAuthButton {
    [PPFunc pp_playTapEffect];


    UIImage *warnIcon = [UIImage systemImageNamed:@"power.circle.fill"];
    // __weak typeof(self) weakSelf = self;


    [PPAlertHelper showConfirmationIn:self
                                title:kLang(@"Logout_Confirm_Title")
                             subtitle:kLang(@"Logout_Confirm_Message")
                          placeholder:nil
                        confirmButton:kLang(@"Confirm")
                         cancelButton:kLang(@"Cancel")
                                 icon:warnIcon
                         confirmBlock:^{
        // do the logout
        [[UserManager shared] signOut];

        // optional: if you use Face ID for login, clear saved creds
        // [BiometricHelper clearCredentials];

        // Flip to dashboard (SceneDelegate listens)
        [[NSNotificationCenter defaultCenter]
         postNotificationName:UserManagerAuthStateDidChangeNotification object:nil];

        // success feedback
        [PPAlertHelper showSuccessIn:self
                               title:kLang(@"Success")
                            subtitle:kLang(@"Logged out successfully")];

        // keep your toast too (optional)

        [PPToast toast:kLang(@"Logged out successfully") style:PPToastStyleSuccess haptic:YES duration:2.0 position:PPToastPositionBottom inView:self.tableView];
    } cancelBlock:nil];



}











/*



 // already logged in? -> nothing to do
 if ([FIRAuth auth].currentUser) return;

 // disabled due to non-admin last time?
 if ([[NSUserDefaults standardUserDefaults] boolForKey:kBiometricDisabledUntilManualLogin]) {
 DLog(@"[Biometric] disabled until manual admin login → skipping auto-auth");
 return;
 }

 // don't schedule twice + need stored creds
 if (self.didScheduleAutoFaceID || ![BiometricHelper hasStoredCredentials]) return;
 self.didScheduleAutoFaceID = YES;

 self.pendingAutoBlock = dispatch_block_create(0, ^{
 [BiometricHelper authenticateFrom:weakSelf delay:0 completion:^(NSString *email, NSString *password, NSError *err) {
 if (err) { DLog(@"[Biometric] auto-auth failed: %@", err.localizedDescription); return; }

 // Firebase sign-in
 [[FIRAuth auth] signInWithEmail:email password:password completion:^(FIRAuthDataResult * _Nullable result, NSError * _Nullable err2) {
 if (err2) { [PPAlertHelper showErrorIn:weakSelf title:kLang(@"Error") subtitle:err2.localizedDescription]; return; }

 FIRUser *user = result.user;
 [user getIDTokenResultWithCompletion:^(FIRAuthTokenResult * _Nullable tokenResult, NSError * _Nullable err3) {
 if (err3) { [PPAlertHelper showErrorIn:weakSelf title:kLang(@"Error") subtitle:kLang(@"StatusFetchClaims")]; return; }

 BOOL isAdmin = [tokenResult.claims[@"admin"] boolValue];
 if (!isAdmin) {
 // 🔴 Non-admin creds → disable Face ID auto & clear saved creds to stop the loop
 DLog(@"[Biometric] saved creds are NOT admin → disabling Face ID auto");
 [BiometricHelper clearCredentials];
 [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kBiometricDisabledUntilManualLogin];
 [[NSUserDefaults standardUserDefaults] synchronize];

 [PPAlertHelper showErrorIn:weakSelf title:kLang(@"Error") subtitle:kLang(@"StatusNoAccess")];
 [UserManager.shared signOut];
 return; // do NOT re-schedule
 }

 // ✅ Admin path
 [[UserManager shared] ensureUserDocumentExistsForAuthUser:user completion:^(__unused UserModel * _Nullable userModel, NSError * _Nullable e3) {
 if (e3) { [PPAlertHelper showErrorIn:weakSelf title:kLang(@"Error") subtitle:kLang(@"StatusUserDocError")]; return; }

 [[UserManager shared] startListeningUserWithUID:user.uid onChange:^(__unused UserModel * _Nullable u) {}];
 // ✅ NAVIGATION HANDOFF — SceneDelegate will switch root
 [[NSNotificationCenter defaultCenter] postNotificationName:UserManagerAuthStateDidChangeNotification
 object:nil];
 //return; // do not push / pop here
 [PPToast toast:kLang(@"Login successful") style:PPToastStyleSuccess haptic:YES duration:2.0 position:PPToastPositionTop inView:self.tableView];


 }];
 }];
 }];
 }];
 });



 */
@end
