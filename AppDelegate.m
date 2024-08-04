#import <Foundation/Foundation.h>
#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

@interface AppDelegate : NSObject
@end

#if __has_include(<UIKit/UIKit.h>)
@interface AppDelegate () <UIApplicationDelegate>
#else
@interface AppDelegate () <NSApplicationDelegate>
#endif
@end

@implementation AppDelegate {
    void (*_runFunction)(void);
}

- (void)setRunFunction:(void(*)(void))runFunction __attribute__((objc_direct)) {
    _runFunction = runFunction;
}

#if __has_include(<UIKit/UIKit.h>)
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_runFunction) self->_runFunction();
    });
    return YES;
}
#else
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_runFunction) self->_runFunction();
    });
}
#endif

@end
