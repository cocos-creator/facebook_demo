/****************************************************************************
 Copyright (c) 2010-2013 cocos2d-x.org
 Copyright (c) 2013-2016 Chukong Technologies Inc.
 Copyright (c) 2017-2018 Xiamen Yaji Software Co., Ltd.

 http://www.cocos2d-x.org

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
****************************************************************************/

#import "AppController.h"
#import "cocos2d.h"
#import "AppDelegate.h"
#import "RootViewController.h"
#import "platform/ios/CCEAGLView-ios.h"
#include "cocos/scripting/js-bindings/jswrapper/SeApi.h"
#import "cocos-analytics/CAAgent.h"

#import <Bolts/Bolts.h>
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLiveStreamingKit/FBSDKLiveStreamingKit.h>

using namespace cocos2d;

@implementation AppController

Application* app = nullptr;
static FBSDKLiveStreamingConfig *_liveStreamingConfig;
@synthesize window;

#pragma mark -
#pragma mark Application lifecycle


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    [CAAgent enableDebug:NO];

    // Add the view controller's view to the window and display.
    float scale = [[UIScreen mainScreen] scale];
    CGRect bounds = [[UIScreen mainScreen] bounds];
    window = [[UIWindow alloc] initWithFrame: bounds];

    // cocos2d application instance
    app = new AppDelegate(bounds.size.width * scale, bounds.size.height * scale);
    app->setMultitouch(true);

    // Use RootViewController to manage CCEAGLView
    _viewController = [[RootViewController alloc]init];
    _viewController.wantsFullScreenLayout = YES;

    // Set RootViewController to window
    if ( [[UIDevice currentDevice].systemVersion floatValue] < 6.0)
    {
        // warning: addSubView doesn't work on iOS6
        [window addSubview: _viewController.view];
    }
    else
    {
        // use this method on ios6
        [window setRootViewController:_viewController];
    }

    [window makeKeyAndVisible];

    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    
    [[FBSDKApplicationDelegate sharedInstance] application:application
                             didFinishLaunchingWithOptions:launchOptions];
    
    FBSDKLiveStreamingManager *liveStreamManager = [FBSDKLiveStreamingManager getInstance];
    [liveStreamManager addObserver:self];
    
    _liveStreamingConfig = [FBSDKLiveStreamingConfig new];
    _liveStreamingConfig.useMic = YES;
    _liveStreamingConfig.useCamera = YES;
    
    
    //run the cocos2d-x game scene
    app->start();
    return YES;
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    
    BOOL handled = [[FBSDKApplicationDelegate sharedInstance] application:application
                                                                  openURL:url
                                                        sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]
                                                               annotation:options[UIApplicationOpenURLOptionsAnnotationKey]
                    ];
    return handled;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    /*
      Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
      Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    */
    // We don't need to call this method any more. It will interrupt user defined game pause&resume logic
    /* cocos2d::Director::getInstance()->pause(); */
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    /*
      Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    */
    // We don't need to call this method any more. It will interrupt user defined game pause&resume logic
    /* cocos2d::Director::getInstance()->resume(); */
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    /*
      Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
      If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
    */
    cocos2d::Application::getInstance()->applicationDidEnterBackground();
    [CAAgent onPause];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    /*
      Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
    */
    auto glview = (__bridge CCEAGLView*)(cocos2d::Application::getInstance()->getView());
    auto currentView = [[[[UIApplication sharedApplication] keyWindow] subviews] lastObject];
    if (glview == currentView) {
        cocos2d::Application::getInstance()->applicationWillEnterForeground();
        [CAAgent onResume];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application {
    /*
     Called when the application is about to terminate.
     See also applicationDidEnterBackground:.
     */
    delete app;
    app = nullptr;
    [CAAgent onDestroy];
}


#pragma mark -
#pragma mark Memory management

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    /*
      Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
    */
}

- (void)onLiveStreamingEnded:(NSNotification *)notification {
    
}

- (void)onLiveStreamingError:(NSNotification *)notification { 
    
}

- (void)onLiveStreamingStarted:(NSNotification *)notification { 
    
}

- (void)onLiveStreamingStatus:(NSNotification *)notification {
    FBSDKLiveStreamingStatus *status = (FBSDKLiveStreamingStatus *)notification.userInfo[FBSDKLiveStreamingStatusKey];
    NSString *execStr = [NSString stringWithFormat:@"cc.live_demo.live_status_changed('%lu')",(unsigned long)status.code];
    se::ScriptEngine::getInstance()->evalString([execStr UTF8String]);
}

#pragma mark -
#pragma mark static function

+(void)startLive{
    FBSDKLiveStreamingManager *liveStreamManager = [FBSDKLiveStreamingManager getInstance];
    FBSDKLiveStreamingCapability *liveStreamingCapability = [liveStreamManager getLiveStreamingCapability];
    if (liveStreamingCapability.code != FBSDKLiveStreamingCapabilityCodeReady) {
        NSLog(@"%@", liveStreamingCapability);
        return;
    }
    
    if ([liveStreamManager isReadyToStartNewStream]) {
        [liveStreamManager startLiveStreamWithLiveStreamingConfig:_liveStreamingConfig];
    }
}

+(void)pauseLive{
    FBSDKLiveStreamingManager *liveStreamManager = [FBSDKLiveStreamingManager getInstance];
    [liveStreamManager pauseLiveStreaming];
}

+(void)resumeLive{
    FBSDKLiveStreamingManager *liveStreamManager = [FBSDKLiveStreamingManager getInstance];
    [liveStreamManager continueLiveStreaming];
}

+(void)stopLive{
    FBSDKLiveStreamingManager *liveStreamManager = [FBSDKLiveStreamingManager getInstance];
    [liveStreamManager stopLiveStreaming];
}

@end
