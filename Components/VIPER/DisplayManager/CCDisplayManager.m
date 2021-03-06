////////////////////////////////////////////////////////////////////////////////
//
//  FANHUB
//  Copyright 2016 FanHub Pty Ltd
//  All Rights Reserved.
//
//  NOTICE: Prepared by AppsQuick.ly on behalf of FanHub. This software
//  is proprietary information. Unauthorized use is prohibited.
//
////////////////////////////////////////////////////////////////////////////////

#import "CCDisplayManager.h"
#import "TyphoonComponentFactory.h"
#import "UIViewController+CCTransitionHandler.h"
#import "CCWorkflow.h"
#import "MTTimingFunctions.h"
#import <UIView+MTAnimation.h>
#import "CCMacroses.h"
#import "NSMutableArray+CCSafeAddRemove.h"


@implementation CCDisplayManager

//-------------------------------------------------------------------------------------------
#pragma mark - Initialization & Destruction
//-------------------------------------------------------------------------------------------

- (void)setupWindow:(UIWindow *)window factory:(TyphoonComponentFactory *)factory
{
    NSParameterAssert(self.initialWorkflow);

    [self setupWindow:window factory:factory viewController:[self.initialWorkflow initialViewController]];
}

- (void)setupWindow:(UIWindow *)window factory:(TyphoonComponentFactory *)factory viewController:(UIViewController *)viewController
{
    _window = window;
    _factory = factory;

    _window.rootViewController = viewController;
    [_window makeKeyAndVisible];
}

//-------------------------------------------------------------------------------------------
#pragma mark - Interface Methods
//-------------------------------------------------------------------------------------------

- (void)replaceRootViewControllerWith:(UIViewController *)viewController animation:(CCDisplayManagerTransitionAnimation)animation
{
    void(^change)() = ^{
        _window.rootViewController = viewController;
    };
    
    [CCDisplayManager animateChange:change onWindow:self.window withAnimtion:animation];
}

- (id <CCModulePromise>)openModuleWithURL:(NSURL *)url transition:(CCTransitionStyle)style
{
    return [_window.rootViewController openModuleUsingURL:url transition:style];
}

+ (void)animateChange:(dispatch_block_t)change onWindow:(UIWindow *)window withAnimtion:(CCDisplayManagerTransitionAnimation)animation
{
    if (animation == CCDisplayManagerTransitionAnimationNone) {
        CCSafeCall(change);
    } else if (animation == CCDisplayManagerTransitionAnimationPush) {
        CGFloat duration = 0.55;
        UIView *snapShotView = [window snapshotViewAfterScreenUpdates:YES];

        UIView *darkenView = [[UIView alloc] initWithFrame:snapShotView.bounds];
        darkenView.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
        [snapShotView addSubview:darkenView];

        CCSafeCall(change);

        [[window.rootViewController.view superview] insertSubview:snapShotView atIndex:0];

        CGRect frame = window.rootViewController.view.frame;
        frame.origin.x = frame.size.width;
        window.rootViewController.view.frame = frame;

        NSMutableArray<UIView *> *views = NSMutableArray.new;

        NSAssert(window.rootViewController.view != nil, nil);
        [views cc_safeAddObject:window.rootViewController.view];

        NSAssert(snapShotView != nil, nil);
        [views cc_safeAddObject:snapShotView];

        NSAssert(darkenView != nil, nil);
        [views cc_safeAddObject:darkenView];

        [UIView mt_animateWithViews:views
                           duration:duration
                     timingFunction:MTTimingFunctionEaseOutExpo animations:^{
                    CGRect snapshotFrame = snapShotView.frame;
                    snapshotFrame.origin.x = -snapShotView.frame.size.width / 3;
                    snapShotView.frame = snapshotFrame;

                    CGRect rootControllerFrame = window.rootViewController.view.frame;
                    rootControllerFrame.origin.x = 0;
                    window.rootViewController.view.frame = rootControllerFrame;
                }        completion:^{
                    [snapShotView removeFromSuperview];
                }];

        [UIView animateWithDuration:duration animations:^{
            darkenView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3f];
        }];

        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] endIgnoringInteractionEvents];
        });
    } else {
        [CATransaction begin];

        CCSafeCall(change);

        CATransition *transition = [CATransition animation];

        transition.duration = 0.3f;
        switch (animation) {
        default:
        case CCDisplayManagerTransitionAnimationSlideUp:
            transition.type = kCATransitionMoveIn;
            transition.subtype = kCATransitionFromTop;
            break;
        case CCDisplayManagerTransitionAnimationSlideDown:
            transition.type = kCATransitionReveal;
            transition.subtype = kCATransitionFromBottom;;
            break;
        }
        transition.fillMode = kCAFillModeForwards;

        transition.removedOnCompletion = YES;
        [transition setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];

        [[UIApplication sharedApplication].keyWindow.layer addAnimation:transition forKey:@"transition"];
        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (transition.duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] endIgnoringInteractionEvents];
        });

        [CATransaction commit];
    };
}

- (CGSize)screenSize
{
    return [UIScreen mainScreen].bounds.size;
}

- (CGRect)screenBounds
{
    CGSize screenSize = [self screenSize];
    return CGRectMake(0, 0, screenSize.width, screenSize.height);
}

- (CGRect)windowFrame
{
    return [UIScreen mainScreen].bounds;
}

@end
