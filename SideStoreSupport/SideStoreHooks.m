//
//  SideStoreHooks.m
//  LiveContainer
//
//  Created by s s on 2026/8/6.
//
#include "../LiveContainer/utils.h"
#include "../LiveContainer/LCSharedUtils.h"
#include "XPCServer.h"
#import <sys/sysctl.h>
@import UserNotifications;
@import UIKit;

@interface LCAuthorizedNotificationSettings : UNNotificationSettings
@end

@implementation LCAuthorizedNotificationSettings

- (UNAuthorizationStatus)authorizationStatus {
    return UNAuthorizationStatusAuthorized;
}

@end

static NSMutableDictionary<NSString *, UIWindow *> *SSVersionWindows;
static id SSSceneObserver;

@interface PassthroughWindow : UIWindow
@end

@implementation PassthroughWindow

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    return nil;
}

@end

@implementation UNUserNotificationCenter(SideStoreHooks)

- (void)lc_addNotificationRequest:(UNNotificationRequest*)request
            withCompletionHandler:(void (^)(NSError* error))completionHandler {
    LiveProcessSideStoreHandler* handler = [PrivClass(LiveProcessSideStoreHandler) shared];
    [handler.server addNotificationRequest:request];
    if (completionHandler) {
        completionHandler(nil);
    }
}

- (void)lc_removePendingNotificationRequestsWithIdentifiers:(NSArray<NSString*>*)identifiers {
    LiveProcessSideStoreHandler* handler = [PrivClass(LiveProcessSideStoreHandler) shared];
    [handler.server removePendingNotificationRequestsWithIdentifiers:identifiers];
}

- (void)lc_getNotificationSettingsWithCompletionHandler:(void (^)(UNNotificationSettings* settings))completionHandler {
    if (!completionHandler) {
        return;
    }

    UNNotificationSettings* settings = class_createInstance(LCAuthorizedNotificationSettings.class, 0);
    completionHandler(settings);
}

@end

@implementation NSBundle(SideStoreHooks)

+ (NSString*)hook_appbundleIdentifier {
    return @"com.kdt.livecontainer";
}

+ (NSString*)hook_storeAppBundleIdentifier {
    return @"com.kdt.livecontainer";
}

- (NSString*)hook_altstoreAppGroup {
    return LCSharedUtils.appGroupID;
}

+ (NSString*)hook_baseAltStoreAppGroupID {
    return @"group.com.SideStore.SideStore";
}

+ (NSBundle*)hook_activeBundle {
    if (!NSUserDefaults.isLiveProcess) return NSUserDefaults.lcMainBundle;
    
    static NSBundle* lcAppBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lcAppBundle = [NSBundle bundleWithURL: NSUserDefaults.lcMainBundle.bundleURL.URLByDeletingLastPathComponent.URLByDeletingLastPathComponent];
    });
    return lcAppBundle;
}

@end

NSURL* SideStoreSource_hook_altStoreSourceURL(id self, SEL cmd) {
    static NSURL* sourceURL = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sourceURL = [NSURL URLWithString:@"https://github.com/LiveContainer/LiveContainer/releases/download/1.0/apps_ss_lc.json"];
    });
    return sourceURL;
}
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
void (*SideStoreMyAppsViewController_orig_viewDidload)(UICollectionViewController* self, SEL cmd) = nil;
void SideStoreMyAppsViewController_hook_viewDidload(UICollectionViewController* self, SEL cmd) {
    if(!SideStoreMyAppsViewController_orig_viewDidload) return;
    SideStoreMyAppsViewController_orig_viewDidload(self, cmd);
    
    UIImage *escapeImage = [UIImage systemImageNamed:@"escape"];
    UIBarButtonItem *escapeItem = [[UIBarButtonItem alloc] initWithImage:escapeImage
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(escapeButtonTapped:)];
        
    NSMutableArray* oldToolBarItems = [self.navigationItem.leftBarButtonItems mutableCopy];
    [oldToolBarItems addObject:escapeItem];
    self.navigationItem.leftBarButtonItems = oldToolBarItems;
}

void SideStoreMyAppsViewController_hook_escapeButtonTapped(UICollectionViewController* self, SEL cmd, id target) {
    [LCSharedUtils launchToGuestAppWithClassicMode:0];
}





static void SSInstallVersionWindow(UIWindowScene *windowScene)
{
    NSString *identifier = windowScene.session.persistentIdentifier;
    if (identifier.length == 0 || SSVersionWindows[identifier] != nil) {
        return;
    }
    
    
    NSString* LCVersion = [NSString stringWithFormat:@"%@-%@",
                         NSUserDefaults.lcMainBundle.infoDictionary[@"CFBundleShortVersionString"],
                         NSUserDefaults.lcMainBundle.infoDictionary[@"LCVersionInfo"]];
    
    NSString* SSVersion = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    
    NSString *osVersion = [[UIDevice currentDevice] systemVersion];
    size_t size = 32;
    char iosBuild[32];
    sysctlbyname("kern.osversion", iosBuild, &size, NULL, 0);
    bool isPhone = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone;
    NSString* allVersionString = [NSString stringWithFormat:isPhone ? @"LC %@, SS %@\niOS %@ (%s)" : @"LC %@, SS %@, iOS %@ (%s)", LCVersion, SSVersion, osVersion, iosBuild];

    UILabel* versionLabel = [UILabel new];
    versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    versionLabel.font = [UIFont systemFontOfSize:9 weight:UIFontWeightRegular];
    versionLabel.textColor = UIColor.labelColor;
    versionLabel.textAlignment = NSTextAlignmentCenter;
    versionLabel.userInteractionEnabled = NO;
    versionLabel.text = allVersionString;
    versionLabel.numberOfLines = 0;
    versionLabel.lineBreakMode = NSLineBreakByWordWrapping;
    
    UIViewController *rootController = [[UIViewController alloc] init];
    rootController.view.backgroundColor = UIColor.clearColor;
    [rootController.view addSubview:versionLabel];
    
    if(windowScene.keyWindow.safeAreaInsets.bottom == 0) {
        // old devices with no bottom safe area
        [NSLayoutConstraint activateConstraints:@[
            [versionLabel.centerXAnchor constraintEqualToAnchor:rootController.view.centerXAnchor],
            [versionLabel.topAnchor constraintEqualToAnchor: rootController.view.safeAreaLayoutGuide.topAnchor]
        ]];
    } else {
        // new devices
        [NSLayoutConstraint activateConstraints:@[
            [versionLabel.centerXAnchor constraintEqualToAnchor:rootController.view.centerXAnchor],
            [versionLabel.bottomAnchor constraintEqualToAnchor: rootController.view.safeAreaLayoutGuide.bottomAnchor
                                                      constant: isPhone ? 22 : 0]
        ]];
    }
    PassthroughWindow *window = [[PassthroughWindow alloc] initWithWindowScene:windowScene];

    window.rootViewController = rootController;
    window.backgroundColor = UIColor.clearColor;

    window.windowLevel = UIWindowLevelAlert;

    window.hidden = NO;

    SSVersionWindows[identifier] = window;
}


// Install the RAM+ observer into newly-created sessions and the shared session.
// The protocol itself only accepts Apple's App ID list endpoint with an active request.
@implementation NSURLSessionConfiguration(BloomBoxRAM)
- (NSArray<Class> *)bb_ramProtocolClasses {
    NSArray<Class> *original = [self bb_ramProtocolClasses] ?: @[];
    Class protocol = NSClassFromString(@"BloomBoxRAMProtocol");
    if (!protocol || [original containsObject:protocol]) return original;
    return [@[protocol] arrayByAddingObjectsFromArray:original];
}
@end

// BloomBox login repair for the pinned SideStore 0.7.0 framework.
// The original authentication flow remains entirely in SideStore. This panel
// only performs the same public metadata request as Remote Server Sync.
// No access to account text fields, Apple login requests, Keychain or ADI.
#import "BloomBoxAnisettePolicy.h"
#import <objc/runtime.h>
#import <objc/message.h>

static NSString *BBAnisetteText(NSString *es, NSString *en) {
    NSString *language = NSBundle.mainBundle.preferredLocalizations.firstObject ?: NSLocale.preferredLanguages.firstObject;
    return [language.lowercaseString hasPrefix:@"es"] ? es : en;
}

static UIButton *BBFindSignInButton(UIView *view, UIViewController *controller) {
    if ([view isKindOfClass:UIButton.class]) {
        UIButton *button = (UIButton *)view;
        if ([[button actionsForTarget:controller forControlEvent:UIControlEventPrimaryActionTriggered] containsObject:@"authenticate"])
            return button;
    }
    for (UIView *child in view.subviews) {
        UIButton *button = BBFindSignInButton(child, controller);
        if (button) return button;
    }
    return nil;
}

static BOOL BBAnisetteInstallerSeeded(void) {
    const char *home = getenv("LC_HOME_PATH");
    if (!home || !home[0]) return NO;
    NSString *root = [NSString stringWithUTF8String:home];
    if (!root.isAbsolutePath) return NO;
    NSString *marker = [root stringByAppendingPathComponent:@"Library/Application Support/BloomBoxInstallerPairingHandoff-v1"];
    // Existence only. Do not read the pairing file.
    return [NSFileManager.defaultManager fileExistsAtPath:marker];
}

static BOOL BBAnisetteMacServerIsActive(void) {
    NSURL *docs = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *catalog = [docs URLByAppendingPathComponent:@"anisette-servers.json"];
    if (!catalog) return NO;
    NSNumber *size = nil;
    if (![catalog getResourceValue:&size forKey:NSURLFileSizeKey error:nil] || size.unsignedLongLongValue > 1024 * 1024) return NO;
    NSData *data = [NSData dataWithContentsOfURL:catalog];
    if (!data) return NO;
    return BBAnisetteCatalogContainsMacServer([NSJSONSerialization JSONObjectWithData:data options:0 error:nil]);
}

@interface BBAnisetteLoginPanel : NSObject <NSURLSessionTaskDelegate>
@property(nonatomic, weak) UIViewController *controller;
@property(nonatomic, weak) UIButton *signInButton;
@property(nonatomic, strong) UIButton *repairButton;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UIActivityIndicatorView *spinner;
@property(nonatomic, assign) BOOL busy;
@property(nonatomic, assign) BOOL manual;
@property(nonatomic, assign) BOOL autoAttempted;
- (void)startManualRepair;
- (void)startSync:(BOOL)manual;
@end

@implementation BBAnisetteLoginPanel
- (BOOL)authenticationBusy {
    SEL selector = NSSelectorFromString(@"isIndicatingActivity");
    if (![self.signInButton respondsToSelector:selector]) return !self.signInButton.userInteractionEnabled;
    BOOL (*readActivity)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
    return readActivity(self.signInButton, selector);
}

- (void)finish:(BOOL)success message:(NSString *)message {
    self.busy = NO;
    [self.spinner stopAnimating];
    self.repairButton.enabled = YES;
    self.statusLabel.textColor = success ? [UIColor colorWithRed:0.65 green:1 blue:0.72 alpha:1] : [UIColor colorWithWhite:1 alpha:0.85];
    self.statusLabel.text = message;
}

- (void)startManualRepair {
    if (self.busy) return;
    if ([self authenticationBusy]) {
        self.statusLabel.text = BBAnisetteText(@"Termina el inicio de sesión antes de reparar.", @"Finish signing in before repairing.");
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:BBAnisetteText(@"Reparar conexión", @"Repair connection")
        message:BBAnisetteText(@"Se sincronizará la configuración pública de jkcoxson (Mac). No se borrarán tu certificado, tus credenciales ni el pairing. Si persiste el error, usa Reset adi.pb en los ajustes de SideStore.", @"Sync public configuration from jkcoxson (Mac). Your certificate, credentials and pairing will not be deleted. If the error persists, use Reset adi.pb in SideStore settings.")
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BBAnisetteText(@"Cancelar", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    __weak BBAnisetteLoginPanel *weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:BBAnisetteText(@"Sincronizar", @"Sync") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf startSync:YES];
    }]];
    [self.controller presentViewController:alert animated:YES completion:nil];
}

- (void)applyOverrides:(NSDictionary *)overrides remainingChecks:(NSUInteger)remaining {
    if (!self.controller.viewIfLoaded.window || [self authenticationBusy]) {
        [self finish:NO message:BBAnisetteText(@"Sin cambios. Vuelve a intentar la reparación.", @"No changes. Try repair again.")];
        return;
    }
    NSUserDefaults *prefs = NSUserDefaults.standardUserDefaults;
    if (!self.manual && !BBAnisetteShouldAutoSync(prefs.dictionaryRepresentation, BBAnisetteInstallerSeeded())) {
        [self finish:NO message:BBAnisetteText(@"Configuración existente conservada.", @"Existing configuration preserved.")];
        return;
    }
    if (!BBAnisetteMacServerIsActive()) {
        // The original login controller populates the official catalog
        // asynchronously. Never overwrite its catalog or unhide servers.
        if (remaining > 0) {
            __weak BBAnisetteLoginPanel *weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf applyOverrides:overrides remainingChecks:remaining - 1];
            });
        } else {
            [self finish:NO message:BBAnisetteText(@"Servidor no disponible en la lista activa. Revisa Anisette Servers y reintenta.", @"Server unavailable in the active list. Check Anisette Servers and retry.")];
        }
        return;
    }
    // The native AnisetteConfigManager resolves these preferences before its
    // saved JSON file. Apply only after response and catalog validation.
    [overrides enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [prefs setObject:value forKey:key];
    }];
    [prefs setBool:NO forKey:@"useOnDeviceAnisette"];
    [prefs setBool:YES forKey:@"disableAnisetteRotation"];
    [prefs setObject:BBAnisetteMacServer forKey:@"menuAnisetteURL"];
    [prefs setBool:YES forKey:BBAnisetteSyncKey];
    [self finish:YES message:self.manual ?
        BBAnisetteText(@"Anisette sincronizado. Si falla, usa Reset adi.pb (Keep Headers).", @"Anisette synced. If sign-in fails, use Reset adi.pb (Keep Headers).") :
        BBAnisetteText(@"Anisette sincronizado · Inicia sesión", @"Anisette synced · Sign in")];
}

- (void)startSync:(BOOL)manual {
    if (self.busy || [self authenticationBusy]) return;
    self.manual = manual;
    self.autoAttempted = YES;
    self.busy = YES;
    self.repairButton.enabled = NO;
    self.statusLabel.textColor = [UIColor colorWithWhite:1 alpha:0.85];
    self.statusLabel.text = BBAnisetteText(@"Sincronizando Anisette…", @"Syncing Anisette…");
    [self.spinner startAnimating];

    NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    configuration.HTTPCookieStorage = nil;
    configuration.URLCredentialStorage = nil;
    configuration.HTTPShouldSetCookies = NO;
    configuration.URLCache = nil;
    configuration.timeoutIntervalForRequest = 10;
    configuration.timeoutIntervalForResource = 15;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    NSURL *url = [NSURL URLWithString:[BBAnisetteMacServer stringByAppendingString:@"/v3/client_info"]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    __weak BBAnisetteLoginPanel *weakSelf = self;
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        NSDictionary *overrides = nil;
        if (!error && http.statusCode == 200 && data.length > 0 && data.length <= 32768 &&
            [response.URL.absoluteString isEqualToString:url.absoluteString]) {
            overrides = BBAnisetteOverrides([NSJSONSerialization JSONObjectWithData:data options:0 error:nil]);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            BBAnisetteLoginPanel *panel = weakSelf;
            if (!panel) return;
            if (overrides) [panel applyOverrides:overrides remainingChecks:10];
            else [panel finish:NO message:BBAnisetteText(@"No se pudo sincronizar. Se conservó la configuración anterior.", @"Sync failed. Previous configuration preserved.")];
        });
        [session finishTasksAndInvalidate];
    }];
    [task resume];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
    willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request
    completionHandler:(void (^)(NSURLRequest *))completionHandler {
    completionHandler(nil);
}
@end

static char BBAnisettePanelKey;
static void (*BBAuthOriginalViewDidLoad)(UIViewController *, SEL);
static void (*BBAuthOriginalViewDidAppear)(UIViewController *, SEL, BOOL);
static void (*BBAuthOriginalAuthenticate)(UIViewController *, SEL);

static void BBAuthViewDidLoad(UIViewController *controller, SEL cmd) {
    BBAuthOriginalViewDidLoad(controller, cmd);
    if (objc_getAssociatedObject(controller, &BBAnisettePanelKey)) return;
    UIButton *signIn = BBFindSignInButton(controller.view, controller);
    if (!signIn) {
        // The pinned storyboard exposes only this button as the outlet.
        @try {
            id outlet = [controller valueForKey:@"signInButton"];
            if ([outlet isKindOfClass:UIButton.class]) signIn = outlet;
        } @catch (NSException *exception) {}
    }
    if (![signIn.superview isKindOfClass:UIStackView.class]) return;
    UIStackView *parent = (UIStackView *)signIn.superview;
    NSUInteger index = [parent.arrangedSubviews indexOfObjectIdenticalTo:signIn];
    if (index == NSNotFound) return;
    BBAnisetteLoginPanel *panel = [BBAnisetteLoginPanel new];
    panel.controller = controller;
    panel.signInButton = signIn;
    panel.repairButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
    config.title = BBAnisetteText(@"Reparar conexión", @"Repair connection");
    config.image = [UIImage systemImageNamed:@"arrow.clockwise"];
    config.imagePadding = 7;
    config.baseForegroundColor = UIColor.whiteColor;
    panel.repairButton.configuration = config;
    panel.repairButton.accessibilityIdentifier = @"bloombox.sidestore.repairConnection";
    [panel.repairButton addTarget:panel action:@selector(startManualRepair) forControlEvents:UIControlEventTouchUpInside];
    [panel.repairButton.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    panel.statusLabel = [UILabel new];
    panel.statusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    panel.statusLabel.adjustsFontForContentSizeCategory = YES;
    panel.statusLabel.textColor = [UIColor colorWithWhite:1 alpha:0.75];
    panel.statusLabel.numberOfLines = 0;
    panel.statusLabel.textAlignment = NSTextAlignmentCenter;
    panel.statusLabel.accessibilityIdentifier = @"bloombox.sidestore.anisetteStatus";
    panel.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    panel.spinner.color = UIColor.whiteColor;
    panel.spinner.hidesWhenStopped = YES;
    UIStackView *status = [[UIStackView alloc] initWithArrangedSubviews:@[panel.spinner, panel.statusLabel]];
    status.axis = UILayoutConstraintAxisHorizontal;
    status.alignment = UIStackViewAlignmentCenter;
    status.spacing = 6;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[panel.repairButton, status]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 2;
    [parent insertArrangedSubview:stack atIndex:index + 1];
    [parent setCustomSpacing:8 afterView:signIn];
    objc_setAssociatedObject(controller, &BBAnisettePanelKey, panel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSUserDefaults *prefs = NSUserDefaults.standardUserDefaults;
    BOOL configured = [prefs boolForKey:BBAnisetteSyncKey] ||
        [[prefs stringForKey:@"menuAnisetteURL"] isEqualToString:BBAnisetteMacServer];
    panel.statusLabel.text = configured ? BBAnisetteText(@"Configuración guardada", @"Configuration saved") :
        BBAnisetteText(@"Ayuda de conexión de SideStore", @"SideStore connection help");
}

static void BBAuthViewDidAppear(UIViewController *controller, SEL cmd, BOOL animated) {
    BBAuthOriginalViewDidAppear(controller, cmd, animated);
    BBAnisetteLoginPanel *panel = objc_getAssociatedObject(controller, &BBAnisettePanelKey);
    if (panel && !panel.autoAttempted &&
        BBAnisetteShouldAutoSync(NSUserDefaults.standardUserDefaults.dictionaryRepresentation, BBAnisetteInstallerSeeded()))
        [panel startSync:NO];
}

static void BBAuthAuthenticate(UIViewController *controller, SEL cmd) {
    BBAnisetteLoginPanel *panel = objc_getAssociatedObject(controller, &BBAnisettePanelKey);
    if (panel.busy) return;
    BBAuthOriginalAuthenticate(controller, cmd);
}

static IMP BBInstallAuthMethod(Class cls, SEL sel, IMP replacement) {
    Method method = class_getInstanceMethod(cls, sel);
    if (!method) return NULL;
    IMP original = method_getImplementation(method);
    // Never replace an inherited UIViewController implementation globally.
    if (!class_addMethod(cls, sel, replacement, method_getTypeEncoding(method)))
        method_setImplementation(method, replacement);
    return original;
}

static void BBInstallAnisetteLoginHook(void) {
    Class cls = NSClassFromString(@"SideStore.AuthenticationViewController") ?:
                NSClassFromString(@"AltStore.AuthenticationViewController") ?:
                NSClassFromString(@"AuthenticationViewController");
    if (!cls || ![cls isSubclassOfClass:UIViewController.class] || BBAuthOriginalViewDidLoad) return;
    SEL auth = NSSelectorFromString(@"authenticate");
    if (!class_getInstanceMethod(cls, auth)) return;
    BBAuthOriginalAuthenticate = (void (*)(UIViewController *, SEL))BBInstallAuthMethod(cls, auth, (IMP)BBAuthAuthenticate);
    BBAuthOriginalViewDidAppear = (void (*)(UIViewController *, SEL, BOOL))BBInstallAuthMethod(cls, @selector(viewDidAppear:), (IMP)BBAuthViewDidAppear);
    BBAuthOriginalViewDidLoad = (void (*)(UIViewController *, SEL))BBInstallAuthMethod(cls, @selector(viewDidLoad), (IMP)BBAuthViewDidLoad);
}

void installSideStoreHooks(void) {
    Class ramProtocol = NSClassFromString(@"BloomBoxRAMProtocol");
    if (ramProtocol) {
        [NSURLProtocol registerClass:ramProtocol];
        swizzle(NSURLSessionConfiguration.class, @selector(protocolClasses), @selector(bb_ramProtocolClasses));
    }


    swizzleClassMethod(NSBundle.class, @selector(appbundleIdentifier), @selector(hook_appbundleIdentifier));
    swizzleClassMethod(NSBundle.class, @selector(storeAppBundleIdentifier), @selector(hook_storeAppBundleIdentifier));
    swizzle(NSBundle.class, @selector(altstoreAppGroup), @selector(hook_altstoreAppGroup));
    swizzleClassMethod(NSBundle.class, @selector(activeBundle), @selector(hook_activeBundle));
    swizzleClassMethod(NSBundle.class, @selector(baseAltStoreAppGroupID), @selector(hook_baseAltStoreAppGroupID));
    
    // replace altStoreSourceURL
    Method altStoreSourceURLMethod = class_getClassMethod(PrivClass(Source), @selector(altStoreSourceURL));
    method_setImplementation(altStoreSourceURLMethod, (IMP)SideStoreSource_hook_altStoreSourceURL);
    
    if (!NSUserDefaults.isLiveProcess) {
        BBInstallAnisetteLoginHook();
        // add escape button
        Method viewDidLoadMethod = class_getInstanceMethod(PrivClass(MyAppsViewController), @selector(viewDidLoad));
        SideStoreMyAppsViewController_orig_viewDidload = (void (*)(UICollectionViewController *, SEL))method_getImplementation(viewDidLoadMethod);
        method_setImplementation(viewDidLoadMethod, (IMP)SideStoreMyAppsViewController_hook_viewDidload);
        class_addMethod(PrivClass(MyAppsViewController), @selector(escapeButtonTapped:), (IMP)SideStoreMyAppsViewController_hook_escapeButtonTapped, "v@:@");
        
        // add version number
        SSVersionWindows = [NSMutableDictionary dictionary];

        SSSceneObserver =
        [NSNotificationCenter.defaultCenter addObserverForName:UISceneDidActivateNotification
                                                        object:nil
                                                         queue:NSOperationQueue.mainQueue
                                                    usingBlock:^(NSNotification *notification) {
            UIScene *scene = notification.object;
            
            if ([scene isKindOfClass:UIWindowScene.class]) {
                SSInstallVersionWindow((UIWindowScene *)scene);
            }
        }];
        
        
        
    }
    

}
#pragma clang diagnostic pop

void installSideStoreNotificationHooks(void) {
    swizzle(UNUserNotificationCenter.class,
            @selector(addNotificationRequest:withCompletionHandler:),
            @selector(lc_addNotificationRequest:withCompletionHandler:));
    swizzle(UNUserNotificationCenter.class,
            @selector(removePendingNotificationRequestsWithIdentifiers:),
            @selector(lc_removePendingNotificationRequestsWithIdentifiers:));
    swizzle(UNUserNotificationCenter.class,
            @selector(getNotificationSettingsWithCompletionHandler:),
            @selector(lc_getNotificationSettingsWithCompletionHandler:));
}
