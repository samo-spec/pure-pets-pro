//
//  RoleOptionsViewController.m
//  PurePetsAdmin
//
//  Created by Mohammed Ahmed on 22/08/2025.
//


// RoleOptionsViewController.m
#import "RoleOptionsViewController.h"
#import "RoleOptionCell.h"

@implementation RoleOptionsViewController

- (instancetype)init
{
    // ✅ Use InsetGrouped style
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        //[NavigationStyling applyStyleFor:self title:kLang(@"Role_Title")];
    }
    return self;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // ✅ Background color (adapts to light/dark mode)
        self.tableView.backgroundColor = AppBackgroundClr;

        // ✅ Register custom cell
        [self.tableView registerClass:[RoleOptionCell class] forCellReuseIdentifier:@"RoleOptionCell"];

        // Optional: remove extra separators
        self.tableView.tableFooterView = [UIView new];
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    RoleOptionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"RoleOptionCell" forIndexPath:indexPath];

    XLFormOptionsObject *option = self.rowDescriptor.selectorOptions[indexPath.row];
    cell.titleLabel.text = option.displayText;
    if ([option respondsToSelector:@selector(userInfo)]) {
        NSDictionary *info = [option performSelector:@selector(userInfo)];
        cell.subtitleLabel.text = info[@"desc"] ?: @"";
    }

    // ✅ checkmark for selected
    if ([self.rowDescriptor.value isEqual:option]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}
@end
