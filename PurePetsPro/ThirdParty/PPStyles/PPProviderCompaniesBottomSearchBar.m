#import "PPProviderCompaniesBottomSearchBar.h"

static UIColor *PPProviderCompaniesSearchSurfaceColor(void)
{
    return [[UIColor ppSurface] colorWithAlphaComponent:0.99];
}

static UIColor *PPProviderCompaniesSearchSecondarySurfaceColor(void)
{
    return [[UIColor ppSecondarySurface] colorWithAlphaComponent:0.86];
}

static UIColor *PPProviderCompaniesSearchStrokeColor(void)
{
    return [[UIColor ppSurfaceBorder] colorWithAlphaComponent:0.35];
}

static UIFont *PPProviderCompaniesSearchScaledFont(UIFont *font, UIFontTextStyle textStyle)
{
    UIFont *resolvedFont = font ?: [UIFont preferredFontForTextStyle:textStyle];
    if (@available(iOS 11.0, *)) {
        return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:resolvedFont];
    }
    return resolvedFont;
}

static void PPProviderCompaniesSearchApplyContinuousCorners(UIView *view, CGFloat radius)
{
    view.layer.cornerRadius = radius;
    if (@available(iOS 13.0, *)) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

@interface PPProviderCompaniesBottomSearchBar () <UITextFieldDelegate>
@property (nonatomic, strong) UIButton *searchChromeView;
@property (nonatomic, strong) UIImageView *searchIconView;
@property (nonatomic, strong, readwrite) UITextField *textField;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) NSLayoutConstraint *countWidthConstraint;
@property (nonatomic, weak) UIView *keyboardHostView;
@property (nonatomic, weak) NSLayoutConstraint *keyboardBottomConstraint;
@property (nonatomic, assign, readwrite, getter=isKeyboardEditing) BOOL keyboardEditing;
@property (nonatomic, assign) BOOL didAnimateIn;
@end

@implementation PPProviderCompaniesBottomSearchBar

- (instancetype)initWithPlaceholder:(NSString *)placeholder
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        [self pp_commonInitWithPlaceholder:placeholder];
    }
    return self;
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(UIViewNoIntrinsicMetric, 54.0);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat radius = CGRectGetHeight(self.searchChromeView.bounds) * 0.5;
    PPProviderCompaniesSearchApplyContinuousCorners(self.searchChromeView, radius);
    self.searchChromeView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.searchChromeView.bounds
                                                                           cornerRadius:radius].CGPath;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self applyCurrentTheme];
}

- (void)pp_commonInitWithPlaceholder:(NSString *)placeholder
{
    self.backgroundColor = UIColor.clearColor;
    self.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.isAccessibilityElement = NO;

    self.searchChromeView = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleCapsule];
    self.searchChromeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchChromeView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.searchChromeView.adjustsImageWhenHighlighted = NO;
    self.searchChromeView.showsTouchWhenHighlighted = NO;
    self.searchChromeView.isAccessibilityElement = NO;
    self.searchChromeView.accessibilityElementsHidden = NO;
    if (!PPIOS26()) {
        self.searchChromeView.layer.borderWidth = 1.0;
        self.searchChromeView.layer.masksToBounds = NO;
        PPProviderCompaniesSearchApplyContinuousCorners(self.searchChromeView, 0.0);
    }
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_focusSearchField)];
    tap.cancelsTouchesInView = NO;
    [self.searchChromeView addGestureRecognizer:tap];
    [self addSubview:self.searchChromeView];

    self.searchIconView = [[UIImageView alloc] init];
    self.searchIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.searchIconView.accessibilityElementsHidden = YES;
    [self.searchChromeView addSubview:self.searchIconView];

    self.textField = [[UITextField alloc] init];
    self.textField.translatesAutoresizingMaskIntoConstraints = NO;
    self.textField.borderStyle = UITextBorderStyleNone;
    self.textField.backgroundColor = UIColor.clearColor;
    self.textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.textField.returnKeyType = UIReturnKeySearch;
    self.textField.enablesReturnKeyAutomatically = NO;
    self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.textField.spellCheckingType = UITextSpellCheckingTypeNo;
    self.textField.delegate = self;
    self.textField.textAlignment = Language.alignmentForCurrentLanguage;
    self.textField.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.textField.font = PPProviderCompaniesSearchScaledFont([Styling fontMedium:14.5], UIFontTextStyleSubheadline);
    self.textField.adjustsFontForContentSizeCategory = YES;
    self.textField.accessibilityLabel = kLang(@"PPBottomSearch_Accessibility");
    self.textField.accessibilityTraits |= UIAccessibilityTraitSearchField;
    [self.textField addTarget:self action:@selector(pp_searchTextDidChange:) forControlEvents:UIControlEventEditingChanged];
    [self pp_disableKeyboardAssistantForTextField:self.textField];
    [self.searchChromeView addSubview:self.textField];

    self.countLabel = [[UILabel alloc] init];
    self.countLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.countLabel.font = [Styling fontBold:11.0];
    self.countLabel.textAlignment = NSTextAlignmentCenter;
    self.countLabel.numberOfLines = 1;
    self.countLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    self.countLabel.layer.cornerRadius = 12.0;
    self.countLabel.layer.cornerCurve = kCACornerCurveContinuous;
    self.countLabel.clipsToBounds = YES;
    self.countLabel.hidden = YES;
    self.countLabel.accessibilityTraits = UIAccessibilityTraitStaticText;
    [self.searchChromeView addSubview:self.countLabel];
    self.countWidthConstraint = [self.countLabel.widthAnchor constraintGreaterThanOrEqualToConstant:46.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.searchChromeView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.searchChromeView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.searchChromeView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.searchChromeView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [self.searchIconView.leadingAnchor constraintEqualToAnchor:self.searchChromeView.leadingAnchor constant:15.0],
        [self.searchIconView.centerYAnchor constraintEqualToAnchor:self.searchChromeView.centerYAnchor],
        [self.searchIconView.widthAnchor constraintEqualToConstant:18.0],
        [self.searchIconView.heightAnchor constraintEqualToConstant:18.0],

        [self.countLabel.trailingAnchor constraintEqualToAnchor:self.searchChromeView.trailingAnchor constant:-15.0],
        [self.countLabel.centerYAnchor constraintEqualToAnchor:self.searchChromeView.centerYAnchor],
        self.countWidthConstraint,
        [self.countLabel.heightAnchor constraintEqualToConstant:24.0],

        [self.textField.leadingAnchor constraintEqualToAnchor:self.searchIconView.trailingAnchor constant:9.0],
        [self.textField.trailingAnchor constraintEqualToAnchor:self.searchChromeView.trailingAnchor constant:-60.0],
        [self.textField.topAnchor constraintEqualToAnchor:self.searchChromeView.topAnchor constant:6.0],
        [self.textField.bottomAnchor constraintEqualToAnchor:self.searchChromeView.bottomAnchor constant:-6.0],
    ]];

    [self setPlaceholder:placeholder];
    [self applyCurrentTheme];
}

- (void)installKeyboardAvoidanceInView:(UIView *)view bottomConstraint:(NSLayoutConstraint *)bottomConstraint
{
    if (!view || !bottomConstraint || (self.keyboardHostView == view && self.keyboardBottomConstraint == bottomConstraint)) {
        return;
    }

    [NSNotificationCenter.defaultCenter removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
    self.keyboardHostView = view;
    self.keyboardBottomConstraint = bottomConstraint;
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(pp_keyboardWillShow:)
                                               name:UIKeyboardWillShowNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(pp_keyboardWillHide:)
                                               name:UIKeyboardWillHideNotification
                                             object:nil];
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)pp_disableKeyboardAssistantForTextField:(UITextField *)textField
{
    textField.inputAccessoryView = nil;
    textField.inputAssistantItem.leadingBarButtonGroups = @[];
    textField.inputAssistantItem.trailingBarButtonGroups = @[];
    if (@available(iOS 11.0, *)) {
        textField.smartQuotesType = UITextSmartQuotesTypeNo;
        textField.smartDashesType = UITextSmartDashesTypeNo;
        textField.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
    }
    if (@available(iOS 17.0, *)) {
        textField.inlinePredictionType = UITextInlinePredictionTypeNo;
    }
}

- (void)setPlaceholder:(NSString *)placeholder
{
    self.textField.placeholder = placeholder ?: @"";
    self.textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder ?: @""
                                                                            attributes:@{
        NSForegroundColorAttributeName: [SeconderyTextClr colorWithAlphaComponent:0.62],
        NSFontAttributeName: PPProviderCompaniesSearchScaledFont([Styling fontMedium:14.5], UIFontTextStyleSubheadline)
    }];
}

- (void)setResultCount:(NSInteger)resultCount totalCount:(NSInteger)totalCount
{
    NSInteger safeResult = MAX(0, resultCount);
    NSInteger safeTotal = MAX(0, totalCount);
    self.countLabel.hidden = safeTotal == 0;
    if (safeTotal > 0) {
        self.countLabel.text = [NSString stringWithFormat:kLang(@"PPBottomSearch_Results_Format"), (long)safeResult, (long)safeTotal];
        self.countLabel.accessibilityLabel = self.countLabel.text;
    } else {
        self.countLabel.text = nil;
        self.countLabel.accessibilityLabel = nil;
    }
}

- (void)setSearchText:(NSString *)text notify:(BOOL)notify
{
    self.textField.text = text ?: @"";
    [self pp_applyPremiumSearchChromeAppearanceFocused:self.textField.isFirstResponder animated:NO];
    if (notify && self.textDidChangeHandler) {
        self.textDidChangeHandler(self.textField.text ?: @"");
    }
}

- (void)dismissKeyboard
{
    [self.textField resignFirstResponder];
}

- (void)animateInIfNeeded
{
    if (self.didAnimateIn) return;
    self.didAnimateIn = YES;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.alpha = 1.0;
        self.transform = CGAffineTransformIdentity;
        return;
    }

    self.alpha = 0.0;
    self.transform = CGAffineTransformMakeTranslation(0.0, 16.0);
    [UIView animateWithDuration:0.46
                          delay:0.05
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.alpha = 1.0;
        self.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)applyCurrentTheme
{
    [self pp_applyPremiumSearchChromeAppearanceFocused:self.textField.isFirstResponder animated:NO];
}

- (void)pp_focusSearchField
{
    [self.textField becomeFirstResponder];
}

- (void)pp_searchTextDidChange:(UITextField *)textField
{
    [self pp_applyPremiumSearchChromeAppearanceFocused:YES animated:YES];
    if (self.textDidChangeHandler) {
        self.textDidChangeHandler(textField.text ?: @"");
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (self.submitHandler) {
        self.submitHandler(textField.text ?: @"");
    }
    [self dismissKeyboard];
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    textField.text = @"";
    [self pp_searchTextDidChange:textField];
    return NO;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    self.keyboardEditing = YES;
    [self pp_applyPremiumSearchChromeAppearanceFocused:YES animated:YES];
    if (self.keyboardEditingStateHandler) {
        self.keyboardEditingStateHandler(YES);
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    self.keyboardEditing = NO;
    [self pp_applyPremiumSearchChromeAppearanceFocused:NO animated:YES];
    if (self.keyboardEditingStateHandler) {
        self.keyboardEditingStateHandler(NO);
    }
}

- (void)pp_applyPremiumSearchChromeAppearanceFocused:(BOOL)focused animated:(BOOL)animated
{
    self.searchChromeView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.textField.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.textField.textAlignment = Language.alignmentForCurrentLanguage;

    void (^applyBlock)(void) = ^{
        UIColor *accent = AppPrimaryClr;
        UIColor *surfaceColor = focused
            ? PPProviderCompaniesSearchSurfaceColor()
            : [PPProviderCompaniesSearchSecondarySurfaceColor() colorWithAlphaComponent:0.98];
        UIColor *strokeColor = focused
            ? [accent colorWithAlphaComponent:0.28]
            : PPProviderCompaniesSearchStrokeColor();

        self.searchChromeView.transform = focused && !UIAccessibilityIsReduceMotionEnabled()
            ? CGAffineTransformMakeScale(1.008, 1.008)
            : CGAffineTransformIdentity;
        self.searchChromeView.backgroundColor = PPIOS26() ? AppClearClr : surfaceColor;
        self.searchChromeView.layer.borderColor = strokeColor.CGColor;
        self.searchChromeView.layer.shadowColor = UIColor.blackColor.CGColor;
        self.searchChromeView.layer.shadowOpacity = focused ? 0.062 : 0.032;
        self.searchChromeView.layer.shadowRadius = focused ? 13.0 : 9.0;
        self.searchChromeView.layer.shadowOffset = CGSizeMake(0.0, focused ? 6.0 : 3.0);

        self.textField.textColor = AppPrimaryTextClr;
        self.textField.tintColor = accent;
        self.textField.font = PPProviderCompaniesSearchScaledFont([Styling fontMedium:14.5], UIFontTextStyleSubheadline);
        self.textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:(self.textField.placeholder ?: @"")
                                                                                   attributes:@{
            NSForegroundColorAttributeName: [SeconderyTextClr colorWithAlphaComponent:(focused ? 0.76 : 0.62)],
            NSFontAttributeName: PPProviderCompaniesSearchScaledFont([Styling fontMedium:14.5], UIFontTextStyleSubheadline)
        }];
        self.searchIconView.tintColor = focused
            ? accent
            : [SeconderyTextClr colorWithAlphaComponent:0.72];
        if (@available(iOS 13.0, *)) {
            UIImageSymbolWeight weight = focused ? UIImageSymbolWeightBold : UIImageSymbolWeightSemibold;
            self.searchIconView.image = [[UIImage systemImageNamed:@"magnifyingglass"
                                                   withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15.5 weight:weight]]
                                         imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        self.countLabel.textColor = accent;
        self.countLabel.backgroundColor = [accent colorWithAlphaComponent:0.10];
        self.countLabel.layer.borderWidth = 0.0 / UIScreen.mainScreen.scale;
        self.countLabel.layer.borderColor = [accent colorWithAlphaComponent:0.18].CGColor;
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        applyBlock();
        return;
    }

    [UIView animateWithDuration:focused ? 0.20 : 0.24
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:applyBlock
                     completion:nil];
}

- (void)pp_keyboardWillShow:(NSNotification *)notification
{
    UIView *hostView = self.keyboardHostView;
    NSLayoutConstraint *bottomConstraint = self.keyboardBottomConstraint;
    if (!hostView || !bottomConstraint) return;

    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrameInView = [hostView convertRect:keyboardFrame fromView:nil];
    CGFloat keyboardHeight = CGRectGetHeight(keyboardFrameInView);
    CGFloat bottomOffset = -keyboardHeight - 16.0;
    [self pp_animateKeyboardConstraint:bottomConstraint inView:hostView constant:bottomOffset userInfo:notification.userInfo];
}

- (void)pp_keyboardWillHide:(NSNotification *)notification
{
    UIView *hostView = self.keyboardHostView;
    NSLayoutConstraint *bottomConstraint = self.keyboardBottomConstraint;
    if (!hostView || !bottomConstraint) return;
    [self pp_animateKeyboardConstraint:bottomConstraint inView:hostView constant:-16.0 userInfo:notification.userInfo];
}

- (void)pp_animateKeyboardConstraint:(NSLayoutConstraint *)constraint
                              inView:(UIView *)view
                            constant:(CGFloat)constant
                            userInfo:(NSDictionary *)userInfo
{
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    UIViewAnimationOptions options = (UIViewAnimationOptions)(curve << 16);
    options |= UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction;
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:options
                     animations:^{
        constraint.constant = constant;
        [view layoutIfNeeded];
    } completion:nil];
}

@end
