#import "RNNModalManager.h"
#import "RNNComponentViewController.h"
#import "RNNConvert.h"
#import "ScreenAnimationController.h"
#import "ScreenReversedAnimationController.h"
#import "UIViewController+LayoutProtocol.h"
#import "RNNOverlayWindow.h"

@interface RNNModalManager ()
@property(nonatomic, strong) ScreenAnimationController *showModalTransitionDelegate;
@property(nonatomic, strong) ScreenAnimationController *dismissModalTransitionDelegate;
@end

@implementation RNNModalManager {
    NSMutableArray *_pendingModalIdsToDismiss;
    NSMutableArray *_presentedModals;
    RCTBridge *_bridge;
    RNNModalManagerEventHandler *_eventHandler;
}

- (instancetype)init {
    self = [super init];
    _pendingModalIdsToDismiss = [[NSMutableArray alloc] init];
    _presentedModals = [[NSMutableArray alloc] init];
    return self;
}

- (instancetype)initWithBridge:(RCTBridge *)bridge
                  eventHandler:(RNNModalManagerEventHandler *)eventHandler {
    self = [self init];
    _bridge = bridge;
    _eventHandler = eventHandler;
    return self;
}

- (void)showModal:(UIViewController<RNNLayoutProtocol> *)viewController
         animated:(BOOL)animated
       completion:(RNNTransitionWithComponentIdCompletionBlock)completion {
    if (!viewController) {
        @throw [NSException exceptionWithName:@"ShowUnknownModal"
                                       reason:@"showModal called with nil viewController"
                                     userInfo:nil];
    }

    UIViewController *topVC = [self topPresentedVC];

    if (viewController.presentationController) {
        viewController.presentationController.delegate = self;
    }

    if (viewController.resolveOptionsWithDefault.animations.showModal.hasAnimation) {
        RNNEnterExitAnimation *enterExitAnimationOptions =
            viewController.resolveOptionsWithDefault.animations.showModal;
        _showModalTransitionDelegate = [[ScreenAnimationController alloc]
            initWithContentTransition:enterExitAnimationOptions
                   elementTransitions:enterExitAnimationOptions.elementTransitions
             sharedElementTransitions:enterExitAnimationOptions.sharedElementTransitions
                             duration:enterExitAnimationOptions.maxDuration
                               bridge:_bridge];

        viewController.transitioningDelegate = _showModalTransitionDelegate;
    }
    
    UIModalPresentationStyle presentationStyle = viewController.modalPresentationStyle;
    BOOL isSheet = NO;
    
#if !TARGET_OS_TV
    (presentationStyle == UIModalPresentationFormSheet) || (presentationStyle == UIModalPresentationPageSheet);
    [self animateRootWindow:[NSNumber numberWithBool:isSheet]];
#endif

    [topVC presentViewController:viewController
                        animated:animated
                      completion:^{
                        if (completion) {
                            completion(viewController.layoutInfo.componentId);
                        }

                        [self->_presentedModals addObject:[viewController topMostViewController]];
                      }];
}

- (void)dismissModal:(UIViewController *)viewController
            animated:(BOOL)animated
          completion:(RNNTransitionCompletionBlock)completion {
    if (viewController) {
        [_pendingModalIdsToDismiss addObject:viewController];
        [self removePendingNextModalIfOnTop:completion animated:animated];
    }
}

- (void)dismissAllModalsAnimated:(BOOL)animated completion:(void (^__nullable)(void))completion {
    UIViewController *root = [self rootViewController];
    if (root.presentedViewController) {
        RNNEnterExitAnimation *dismissModalOptions =
            root.presentedViewController.resolveOptionsWithDefault.animations.dismissModal;
        if (dismissModalOptions.hasAnimation) {
            _dismissModalTransitionDelegate = [[ScreenAnimationController alloc]
                initWithContentTransition:dismissModalOptions
                       elementTransitions:dismissModalOptions.elementTransitions
                 sharedElementTransitions:dismissModalOptions.sharedElementTransitions
                                 duration:dismissModalOptions.maxDuration
                                   bridge:_bridge];

            root.presentedViewController.transitioningDelegate = _dismissModalTransitionDelegate;
        }
        
        [self animateRootWindow:[NSNumber numberWithBool:FALSE]];

        [root dismissViewControllerAnimated:animated completion:completion];
        [_eventHandler dismissedMultipleModals:_presentedModals];
        [_pendingModalIdsToDismiss removeAllObjects];
        [_presentedModals removeAllObjects];
    } else if (completion)
        completion();
}

- (void)reset {
    [self animateRootWindow:[NSNumber numberWithBool:FALSE]];
    [_presentedModals removeAllObjects];
    [_pendingModalIdsToDismiss removeAllObjects];
}

#pragma mark - private

- (void)removePendingNextModalIfOnTop:(RNNTransitionCompletionBlock)completion
                             animated:(BOOL)animated {
    UIViewController<RNNLayoutProtocol> *modalToDismiss = [_pendingModalIdsToDismiss lastObject];
    RNNNavigationOptions *optionsWithDefault = modalToDismiss.resolveOptionsWithDefault;

    if (!modalToDismiss) {
        return;
    }

    UIViewController *topPresentedVC = [self topPresentedVC];

    if (optionsWithDefault.animations.dismissModal.hasAnimation) {
        RNNEnterExitAnimation *enterExitAnimationOptions =
            modalToDismiss.resolveOptionsWithDefault.animations.dismissModal;
        _dismissModalTransitionDelegate = [[ScreenReversedAnimationController alloc]
            initWithContentTransition:enterExitAnimationOptions
                   elementTransitions:enterExitAnimationOptions.elementTransitions
             sharedElementTransitions:enterExitAnimationOptions.sharedElementTransitions
                             duration:enterExitAnimationOptions.maxDuration
                               bridge:_bridge];

        [self topViewControllerParent:modalToDismiss].transitioningDelegate =
            _dismissModalTransitionDelegate;
    }

    if ((modalToDismiss == topPresentedVC || [topPresentedVC findViewController:modalToDismiss])) {
        
        [self animateRootWindow:[NSNumber numberWithBool:FALSE]];
        
        [self dismissSearchController:modalToDismiss];
        [modalToDismiss
            dismissViewControllerAnimated:animated
                               completion:^{
                                 [self->_pendingModalIdsToDismiss removeObject:modalToDismiss];
                                 if (modalToDismiss.view) {
                                     [self dismissedModal:modalToDismiss];
                                 }

                                 if (completion) {
                                     completion();
                                 }

                                 [self removePendingNextModalIfOnTop:nil animated:NO];
                               }];
    } else {
        [modalToDismiss.view removeFromSuperview];
        modalToDismiss.view = nil;
        [self dismissedModal:modalToDismiss];

        if (completion)
            completion();
    }
}

- (void)dismissSearchController:(UIViewController *)modalToDismiss {
    if ([modalToDismiss.presentedViewController.class isSubclassOfClass:UISearchController.class]) {
        [modalToDismiss.presentedViewController dismissViewControllerAnimated:NO completion:nil];
    }
}

- (void)dismissedModal:(UIViewController *)viewController {
    [_presentedModals removeObject:[viewController topMostViewController]];
    [self animateRootWindow:nil];
    [_eventHandler dismissedModal:viewController.presentedComponentViewController];
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    [_presentedModals removeObject:presentationController.presentedViewController];
    [self animateRootWindow:nil];
    [_eventHandler dismissedModal:presentationController.presentedViewController
                                      .presentedComponentViewController];
}

- (void)presentationControllerDidAttemptToDismiss:
    (UIPresentationController *)presentationController {
    [_eventHandler attemptedToDismissModal:presentationController.presentedViewController
                                               .presentedComponentViewController];
}

- (void)animateRootWindow:(NSNumber *)willOpenModal {
#if !TARGET_OS_TV
    BOOL openingModal;
    if (willOpenModal != nil) {
        openingModal = [willOpenModal boolValue];
    } else {
        openingModal = (_presentedModals.count > 0);
    }
    
    UIWindow *rootWindow = UIApplication.sharedApplication.delegate.window;
    rootWindow.rootViewController.view.clipsToBounds = YES;
    rootWindow.layer.masksToBounds = YES;
    
    if(openingModal) {
        [UIView animateWithDuration:0.25 animations:^{
            // Set the transform property of your window's view to scale down to 0.1 times its size
            rootWindow.rootViewController.view.transform = CGAffineTransformMakeScale(0.89, 0.89);
            rootWindow.rootViewController.view.layer.cornerRadius = 10;
        }];
    }
    else {
        [UIView animateWithDuration:0.25 animations:^{
            // Set the transform property of your window's view to scale down to 0.1 times its size
            rootWindow.rootViewController.view.transform = CGAffineTransformMakeScale(1, 1);
            rootWindow.rootViewController.view.layer.cornerRadius = 0;
        }];
    }
#endif
}

- (UIViewController *)rootViewController {
    NSArray *allWindows = [[UIApplication sharedApplication] windows];
    UIWindow *topWindow = nil;

    for (UIWindow *window in allWindows) {
        if ([window isKindOfClass:[RNNOverlayWindow class]]) {
            topWindow = window;
        }
    }
    
    if(topWindow == nil)
        topWindow = UIApplication.sharedApplication.delegate.window;
    
    return topWindow.rootViewController;
}

- (UIViewController *)topPresentedVC {
    UIViewController *root = [self rootViewController];
    while (root.presentedViewController && !root.presentedViewController.isBeingDismissed) {
        root = root.presentedViewController;
    }
    return root;
}

- (UIViewController *)topPresentedVCLeaf {
    id root = [self topPresentedVC];
    return [root topViewController] ? [root topViewController] : root;
}

- (UIViewController *)topViewControllerParent:(UIViewController *)viewController {
    UIViewController *topParent = viewController;
    while (topParent.parentViewController) {
        topParent = topParent.parentViewController;
    }

    return topParent;
}

@end
