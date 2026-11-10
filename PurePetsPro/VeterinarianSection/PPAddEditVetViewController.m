//
//  PPAddEditVetViewController.m
//  PurePetsPro
//
//  Reinvented from first principles with SwiftyMax NextGen V9.
//  Hosts the category-defining SwiftUI Clinical Credentialing Studio (PPAddEditVetStudioScreen).
//

#import "PPAddEditVetViewController.h"
#import "PPVetModel.h"
#import "PPDesignTokens.h"
#import "PurePetsPro-Swift.h"

@interface PPAddEditVetViewController ()
@property (nonatomic, strong) PPAddEditVetStudioHostingController *hostingController;
@end

@implementation PPAddEditVetViewController

#pragma mark - Initialization

- (instancetype)initWithVet:(PPVetModel *)vet {
    self = [super init];
    if (self) {
        _vetToEdit = vet;
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    __weak typeof(self) weakSelf = self;
    self.hostingController = [[PPAddEditVetStudioHostingController alloc] initWithVetToEdit:self.vetToEdit onDismiss:^{
        if (weakSelf.navigationController) {
            [weakSelf.navigationController popViewControllerAnimated:YES];
        } else {
            [weakSelf dismissViewControllerAnimated:YES completion:nil];
        }
    }];
    self.hostingController.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    [self addChildViewController:self.hostingController];
    self.hostingController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.hostingController.view];

    [NSLayoutConstraint activateConstraints:@[
        [self.hostingController.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.hostingController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.hostingController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.hostingController.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [self.hostingController didMoveToParentViewController:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleDefault;
}

@end
