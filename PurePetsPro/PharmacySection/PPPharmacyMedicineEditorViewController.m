//
//  PPPharmacyMedicineEditorViewController.m
//  Pure Pets Pro
//
//  SwiftyMax NextGen V9 Category-Defining First-Principles Reinvention
//  Hosts the Sovereign Veterinary Clinical Pharmacology Studio & Living Medicine Dossier (PPPharmacyMedicineStudioView)
//

#import "PPPharmacyMedicineEditorViewController.h"
#import "PPVetManager.h"
#import "Language.h"
#import "Styling.h"
#import "PPDesignTokens.h"
#import "UIViewController+PPNavBar.h"
#import "PPHUD.h"
#import "PPAlertHelper.h"
#import "PurePetsPro-Swift.h"
#import "PetAccessory.h"

@interface PPPharmacyMedicineEditorViewController ()
@property (nonatomic, strong, nullable) PPVetMedicineModel *medicine;
@property (nonatomic, copy) PPPharmacyMedicineEditorCompletion completion;
@property (nonatomic, strong) UIViewController *hostingController;
@end

@implementation PPPharmacyMedicineEditorViewController

- (instancetype)initWithMedicine:(PPVetMedicineModel *)medicine completion:(PPPharmacyMedicineEditorCompletion)completion {
    self = [super init];
    if (self) {
        _medicine = [medicine copy];
        _completion = [completion copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor ppBackground];
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    
    __weak typeof(self) weakSelf = self;
    UIViewController *host = [PPPharmacyMedicineStudioHostingBridge makeViewControllerWithMedicine:self.medicine
                                                                                            onSave:^(PPVetMedicineModel * _Nonnull savedMedicine, UIImage * _Nullable image) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (strongSelf.completion) {
            strongSelf.completion(savedMedicine, image);
        }
    }
                                                                                          onDismiss:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_performBackNavigation];
    }
                                                                                onOpenVariantStudio:^(PPVetMedicineModel * _Nonnull med) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf pp_openVariantStudioForMedicine:med];
    }];
    
    self.hostingController = host;
    [self addChildViewController:host];
    host.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:host.view];
    
    [NSLayoutConstraint activateConstraints:@[
        [host.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [host.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [host.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [host.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    
    [host didMoveToParentViewController:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)pp_openVariantStudioForMedicine:(PPVetMedicineModel *)med {
    if (!med) return;
    PetAccessory *acc = [med asPetAccessory];
    PPAccessoryVariantStudioHostController *host = [[PPAccessoryVariantStudioHostController alloc] initWithAccessory:acc];
    __weak typeof(self) ws = self;
    host.onSaved = ^(PetAccessory *savedAcc) {
        if (!savedAcc) return;
        [med applyVariantAccessory:savedAcc];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:host];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = nav.sheetPresentationController;
        sheet.detents = @[[UISheetPresentationControllerDetent largeDetent]];
        sheet.prefersGrabberVisible = YES;
    }
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)pp_performBackNavigation {
    if (self.navigationController && self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else if (self.presentingViewController || self.navigationController.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
