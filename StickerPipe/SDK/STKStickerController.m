//
//  STKStickerController.m
//  StickerPipe
//
//  Created by Vadim Degterev on 21.07.15.
//  Copyright (c) 2015 908 Inc. All rights reserved.
//

#import "STKStickerController.h"
#import "STKStickerDelegateManager.h"
#import "STKStickerHeaderDelegateManager.h"
#import "STKStickerViewCell.h"
#import "STKStickersSeparator.h"
#import "STKStickerHeaderCell.h"
#import "STKStickerObject.h"
#import "STKUtility.h"
#import "STKStickersEntityService.h"
#import "STKEmptyRecentCell.h"
#import "STKStickersSettingsViewController.h"
#import "STKStickersShopViewController.h"

#import "STKPackDescriptionController.h"
#import "STKStickerPackObject.h"
#import "STKOrientationNavigationController.h"
#import "STKShowStickerButton.h"
#import "STKAnalyticService.h"

//SIZES

static const CGFloat kStickersSectionPaddingTopBottom = 12.0;

@interface STKStickerController() <STKPackDescriptionControllerDelegate>

@property (strong, nonatomic) UIView *keyboardButtonSuperView;

@property (weak, nonatomic) IBOutlet UIView *internalStickersView;

@property (weak, nonatomic) IBOutlet UICollectionView *stickersHeaderCollectionView;

@property (weak, nonatomic) IBOutlet UIButton *collectionsButton;
@property (weak, nonatomic) IBOutlet UIButton *stickersShopButton;
@property (weak, nonatomic) IBOutlet UICollectionView *stickersCollectionView;

@property (strong, nonatomic) STKStickerDelegateManager *stickersDelegateManager;
@property (strong, nonatomic) STKStickerHeaderDelegateManager *stickersHeaderDelegateManager;

@property (strong, nonatomic) STKShowStickerButton *keyboardButton;

@property (assign, nonatomic) BOOL isKeyboardShowed;


@property (strong, nonatomic) STKStickersEntityService *stickersService;

- (IBAction)collectionsButtonAction:(id)sender;
- (IBAction)stickersShopButtonAction:(id)sender;

@end

@implementation STKStickerController

#pragma mark - Inits

- (void)loadStickerPacks
{
    [self.stickersService getStickerPacksWithType:nil completion:^(NSArray *stickerPacks) {
        self.stickersService.stickersArray = stickerPacks;
        self.keyboardButton.badgeView.hidden = ![self.stickersService hasNewPacks];
    } failure:nil];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.internalStickersView = [[[NSBundle mainBundle] loadNibNamed:@"STKStickersView" owner:self options:nil] firstObject];
        self.internalStickersView.backgroundColor = [UIColor whiteColor];
        
        self.stickersService = [STKStickersEntityService new];
        
        
        self.internalStickersView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        self.internalStickersView.clipsToBounds = YES;
        
        //iOS 7 FIX
        if (CGRectEqualToRect(self.internalStickersView.frame, CGRectZero) && [UIDevice currentDevice].systemVersion.floatValue < 8.0) {
            self.internalStickersView.frame = CGRectMake(1, 1, 1, 1);
        }
        
        [self loadStickerPacks];
        
        [self initStickerHeader];
        [self initStickersCollectionView];
        [self initCollectionsButton];
        
        [self reloadStickers];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(willHideKeyboard:)
                                                     name:UIKeyboardWillHideNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didShowKeyboard:)
                                                     name:UIKeyboardWillShowNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storageUpdated:) name:STKStickersCacheDidUpdateStickersNotification object:nil];
        
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(updateStickers) name:STKStickersReorderStickersNotification object:nil];
    }
    return self;
}

- (void)updateStickers {
    [self loadStickerPacks];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) initStickersCollectionView {
    
    self.stickersDelegateManager = [STKStickerDelegateManager new];
    
    __weak typeof(self) weakSelf = self;
    [self.stickersDelegateManager setDidChangeDisplayedSection:^(NSInteger displayedSection) {
        [weakSelf setPackSelectedAtIndex:displayedSection];
    }];
    
    [self.stickersDelegateManager setDidSelectSticker:^(STKStickerObject *sticker) {
        [weakSelf.stickersService incrementStickerUsedCountWithID:sticker.stickerID];
        [[STKAnalyticService sharedService] sendEventWithCategory:STKAnalyticMessageCategory action:STKAnalyticActionSend label:STKMessageStickerLabel value:nil];
        if ([weakSelf.delegate respondsToSelector:@selector(stickerController:didSelectStickerWithMessage:)]) {
            [weakSelf.delegate stickerController:weakSelf didSelectStickerWithMessage:sticker.stickerMessage];
        }
    }];
    
    self.stickersCollectionView.dataSource = self.stickersDelegateManager;
    self.stickersCollectionView.delegate = self.stickersDelegateManager;
    [self.stickersCollectionView registerClass:[STKStickerViewCell class] forCellWithReuseIdentifier:@"STKStickerViewCell"];
    [self.stickersCollectionView registerClass:[STKEmptyRecentCell class] forCellWithReuseIdentifier:@"STKEmptyRecentCell"];
    [self.stickersCollectionView registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"UICollectionReusableView"];
    [self.stickersCollectionView registerClass:[STKStickersSeparator class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"STKStickerPanelSeparator"];
    
    self.stickersDelegateManager.collectionView = self.stickersCollectionView;
}

- (void)initCollectionsButton {
    [self.collectionsButton setTintColor:[STKUtility defaultOrangeColor]];
    self.collectionsButton.backgroundColor = self.headerBackgroundColor ? self.headerBackgroundColor : [STKUtility defaultGreyColor];
}

- (void) initStickerHeader {
    self.stickersHeaderDelegateManager = [STKStickerHeaderDelegateManager new];
    __weak typeof(self) weakSelf = self;
    [self.stickersHeaderDelegateManager setDidSelectRow:^(NSIndexPath *indexPath, STKStickerPackObject *stickerPack) {
        if (stickerPack.isNew.boolValue) {
            stickerPack.isNew = @NO;
            [weakSelf.stickersService updateStickerPackInCache:stickerPack];
            [weakSelf reloadHeaderItemAtIndexPath:indexPath];
        }
        NSIndexPath *newIndexPath = [NSIndexPath indexPathForItem:0 inSection:indexPath.item];
        CGRect layoutRect = [weakSelf.stickersCollectionView layoutAttributesForItemAtIndexPath:newIndexPath].frame;
        
        [weakSelf.stickersCollectionView setContentOffset:CGPointMake(weakSelf.stickersCollectionView.contentOffset.x, layoutRect.origin.y  - kStickersSectionPaddingTopBottom) animated:YES];
        weakSelf.stickersDelegateManager.currentDisplayedSection = indexPath.item;
        
    }];
    
    self.stickersHeaderCollectionView.dataSource = self.stickersHeaderDelegateManager;
    self.stickersHeaderCollectionView.delegate = self.stickersHeaderDelegateManager;
    
    [self.stickersHeaderCollectionView registerClass:[STKStickerHeaderCell class] forCellWithReuseIdentifier:@"STKStickerPanelHeaderCell"];
    
    self.stickersHeaderCollectionView.backgroundColor = self.headerBackgroundColor ? self.headerBackgroundColor : [STKUtility defaultGreyColor];
    
}

- (void)setupInternalStickersView {
    self.internalStickersView = [[[NSBundle mainBundle] loadNibNamed:@"STKStickersView" owner:self options:nil] firstObject];
    
    
    self.internalStickersView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    self.internalStickersView.clipsToBounds = YES;
    
    //iOS 7 FIX
    if (CGRectEqualToRect(self.internalStickersView.frame, CGRectZero) && [UIDevice currentDevice].systemVersion.floatValue < 8.0) {
        self.internalStickersView.frame = CGRectMake(1, 1, 1, 1);
    }
    [self initStickerHeader];
    [self initStickersCollectionView];
    [self initCollectionsButton];
    
}

- (void)addKeyboardButtonConstraintsToView:(UIView *)view {
    self.keyboardButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSLayoutConstraint *width = [NSLayoutConstraint constraintWithItem:self.keyboardButton
                                                             attribute:NSLayoutAttributeWidth
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:nil
                                                             attribute:NSLayoutAttributeNotAnAttribute
                                                            multiplier:1
                                                              constant:33];
    NSLayoutConstraint *height = [NSLayoutConstraint constraintWithItem:self.keyboardButton
                                                              attribute:NSLayoutAttributeHeight
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:nil
                                                              attribute:NSLayoutAttributeNotAnAttribute
                                                             multiplier:1
                                                               constant:33];
    
    NSLayoutConstraint *right = [NSLayoutConstraint constraintWithItem:self.keyboardButton
                                                             attribute:NSLayoutAttributeRight
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:view
                                                             attribute:NSLayoutAttributeRight
                                                            multiplier:1
                                                              constant:0];
    
    NSLayoutConstraint *top = [NSLayoutConstraint constraintWithItem:self.keyboardButton
                                                           attribute:NSLayoutAttributeTop
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:view
                                                           attribute:NSLayoutAttributeTop
                                                          multiplier:1
                                                            constant:0];
    
    [view addConstraints:@[width, height, right,top
                           ]];
}


- (void)initKeyBoardButton {
    self.keyboardButton = [STKShowStickerButton buttonWithType:UIButtonTypeSystem];
    UIImage *buttonImage = [UIImage imageNamed:@"STKShowStickersIcon"];
    [self.keyboardButton setImage:buttonImage forState:UIControlStateNormal];
    [self.keyboardButton addTarget:self action:@selector(keyboardButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    self.keyboardButton.tintColor = [UIColor grayColor];
    self.keyboardButton.badgeView.hidden = ![self.stickersService hasNewPacks];
    
    CGRect frame = CGRectMake(0, 0, self.textInputView.contentSize.width, 33);
    UIView *view = [[UIView alloc]initWithFrame:frame];
    [view addSubview:self.keyboardButton];
    [self.textInputView addSubview:view];
    [self addKeyboardButtonConstraintsToView:view];
    self.keyboardButtonSuperView = view;
}

- (void)updateFrames {
    CGRect frame = CGRectMake(0, 0, self.textInputView.frame.size.width, 33);
    self.keyboardButtonSuperView.frame = frame;
    [self.keyboardButton layoutIfNeeded];
}

#pragma mark - Actions

- (void)collectionsButtonAction:(UIButton*)collectionsButton {
    [self hideStickersView];
    
    STKStickersSettingsViewController *vc = [[STKStickersSettingsViewController alloc] initWithNibName:@"STKStickersSettingsViewController" bundle:nil];
    
    STKOrientationNavigationController *navigationController = [[STKOrientationNavigationController alloc] initWithRootViewController:vc];
    
    UIViewController *presenter = [self.delegate stickerControllerViewControllerForPresentingModalView];
    
    [presenter presentViewController:navigationController animated:YES completion:nil];
}

- (void)stickersShopButtonAction:(id)sender {
    [self hideStickersView];
    
    STKStickersShopViewController *vc = [[STKStickersShopViewController alloc] initWithNibName:@"STKStickersShopViewController" bundle:nil];
    
    STKOrientationNavigationController *navigationController = [[STKOrientationNavigationController alloc] initWithRootViewController:vc];
    
    UIViewController *presenter = [self.delegate stickerControllerViewControllerForPresentingModalView];
    
    [presenter presentViewController:navigationController animated:YES completion:nil];
}

- (void)keyboardButtonAction:(UIButton *)keyboardButton {
    if (self.textInputView.inputView) {
        [self hideStickersView];
        
    } else {
        [self showStickersView];
    }
}


#pragma mark - Reload

- (void)reloadStickersView {
    
    [self reloadStickers];
}

- (void)reloadHeaderItemAtIndexPath:(NSIndexPath*)indexPath {
    NSArray *stickerPacks = self.stickersService.stickersArray;
    [self.stickersHeaderDelegateManager setStickerPacks:stickerPacks];
    [self.stickersHeaderCollectionView reloadItemsAtIndexPaths:@[indexPath]];
    [self.stickersHeaderCollectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
}

- (void)reloadStickersHeader {
    NSArray *stickerPacks = self.stickersService.stickersArray;
    [self.stickersHeaderDelegateManager setStickerPacks:stickerPacks];
    [self.stickersHeaderCollectionView reloadItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:1 inSection:0]]];
    NSIndexPath *selectedIndexPath = [NSIndexPath indexPathForItem:self.stickersDelegateManager.currentDisplayedSection inSection:0];
    [self.stickersHeaderCollectionView selectItemAtIndexPath:selectedIndexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
}

- (void)reloadStickers {
    [self setupInternalStickersView];
    
    NSArray *stickerPacks = self.stickersService.stickersArray;
    [self.stickersDelegateManager setStickerPacksArray:stickerPacks];
    [self.stickersHeaderDelegateManager setStickerPacks:stickerPacks];
    [self.stickersCollectionView reloadData];
    [self.stickersHeaderCollectionView reloadData];
    self.stickersCollectionView.contentOffset = CGPointZero;
    self.stickersDelegateManager.currentDisplayedSection = 0;
    
    [self setPackSelectedAtIndex:0];
}

#pragma mark - Selection

- (void)setPackSelectedAtIndex:(NSInteger)index {
    if ([self.stickersHeaderCollectionView numberOfItemsInSection:0] - 1 >= index) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
        
        STKStickerPackObject *stickerPack = [self.stickersHeaderDelegateManager itemAtIndexPath:indexPath];
        if (stickerPack.isNew.boolValue) {
            stickerPack.isNew = @NO;
            [self.stickersService updateStickerPackInCache:stickerPack];
            [self reloadHeaderItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]];
        }
        [self.stickersHeaderCollectionView selectItemAtIndexPath:indexPath animated:YES scrollPosition:UICollectionViewScrollPositionCenteredHorizontally];
    }
    
}

#pragma mark - STKPackDescriptionControllerDelegate

- (void)packDescriptionControllerDidChangePakcStatus:(STKPackDescriptionController*)controller {
    if ([self.delegate respondsToSelector:@selector(stickerControllerDidChangePackStatus:)]) {
        [self.delegate stickerControllerDidChangePackStatus:self];
    }
}

#pragma mark - Presenting

-(void)showPackInfoControllerWithStickerMessage:(NSString*)message {
    [self hideStickersView];
    STKPackDescriptionController *vc = [[STKPackDescriptionController alloc] initWithNibName:@"STKPackDescriptionController" bundle:nil];
    vc.stickerMessage = message;
    vc.delegate = self;
    UIViewController *presentViewController = [self.delegate stickerControllerViewControllerForPresentingModalView];
    [presentViewController presentViewController:vc animated:YES completion:nil];
}

#pragma mark - Checks

-(BOOL)isStickerPackDownloaded:(NSString *)packMessage {
    NSArray *packNames = [STKUtility trimmedPackNameAndStickerNameWithMessage:packMessage];
    NSString *packName = packNames.firstObject;
    return [self.stickersService isPackDownloaded:packName];
    
}

#pragma mark - Colors

-(void)setColorForStickersHeaderPlaceholderColor:(UIColor *)color {
    self.stickersHeaderDelegateManager.placeholderHeadercolor = color;
}

-(void)setColorForStickersPlaceholder:(UIColor *)color {
    self.stickersDelegateManager.placeholderColor = color;
}

#pragma mark - Property

- (BOOL)isStickerViewShowed {
    
    BOOL isShowed = self.internalStickersView.superview != nil;
    
    return isShowed;
}

-(UIView *)stickersView {
    
    [self reloadStickers];
    
    return _internalStickersView;
}

- (void)setTextInputView:(UITextView *)textInputView {
    _textInputView = textInputView;
    [self initKeyBoardButton];
}

#pragma mark - Show/hide stickers

- (void) showStickersView {
    UIImage *buttonImage = [UIImage imageNamed:@"STKShowKeyboadIcon"];
    
    [self.keyboardButton setImage:buttonImage forState:UIControlStateNormal];
    [self.keyboardButton setImage:buttonImage forState:UIControlStateHighlighted];
    
    self.textInputView.inputView = self.stickersView;
    [self reloadStickersInputViews];
}

- (void) hideStickersView {
    
    UIImage *buttonImage = [UIImage imageNamed:@"STKShowStickersIcon"];
    
    [self.keyboardButton setImage:buttonImage forState:UIControlStateNormal];
    [self.keyboardButton setImage:buttonImage forState:UIControlStateHighlighted];
    
    self.textInputView.inputView = nil;
    
    [self reloadStickersInputViews];
}


- (void) reloadStickersInputViews {
    [self.textInputView reloadInputViews];
    if (!self.isKeyboardShowed) {
        [self.textInputView becomeFirstResponder];
    }
}

#pragma mark - keyboard notifications

- (void) didShowKeyboard:(NSNotification*)notification {
    self.isKeyboardShowed = YES;
}


- (void)willHideKeyboard:(NSNotification*)notification {
    self.isKeyboardShowed = NO;
}

- (void)storageUpdated:(NSNotification*)notification {
    self.keyboardButton.badgeView.hidden = ![self.stickersService hasNewPacks];
}

#pragma mark -------
- (void)textMessageSent:(NSString *)message {
    [[STKAnalyticService sharedService] sendEventWithCategory:STKAnalyticMessageCategory action:STKAnalyticActionSend label:STKMessageTextLabel value:nil];
    
}
@end
