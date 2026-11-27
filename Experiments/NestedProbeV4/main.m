#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <stdio.h>
#include <dlfcn.h>

// Preserve UIKit startup; load SwiftUI only after an explicit test tap.
// All writes are restricted to the selected guest's ordinary Documents folder.
static int storageFD = -1;
static char storageStatus[160] = "Guest storage not checked";
static void mark(const char *message) {
    fprintf(stderr, "[BloomBoxDevV4] %s\n", message);
    if (storageFD < 0) return;
    int fd = openat(storageFD, "BloomBoxDevProbeV4.log", O_WRONLY | O_CREAT | O_APPEND | O_NOFOLLOW | O_NONBLOCK, 0600);
    if (fd < 0) return;
    struct stat st;
    if (fstat(fd, &st) == 0 && S_ISREG(st.st_mode) && st.st_nlink == 1 && st.st_size < 32768) {
        (void)write(fd, message, strlen(message));
        (void)write(fd, "\n", 1);
        (void)fsync(fd);
    }
    close(fd);
}
static void prepareStorage(void) {
    const char *home = getenv("HOME");
    char actual[PATH_MAX], other[PATH_MAX], parent[PATH_MAX];
    if (!home || !realpath(home, actual)) {
        snprintf(storageStatus, sizeof(storageStatus), "Guest HOME missing or inaccessible");
        return;
    }
    const char *keys[] = {"LC_HOME_PATH", "LP_HOME_PATH"};
    for (size_t i = 0; i < sizeof(keys)/sizeof(keys[0]); i++) {
        const char *v = getenv(keys[i]);
        if (v && realpath(v, other) && strcmp(other, actual) == 0) {
            snprintf(storageStatus, sizeof(storageStatus), "Refused outer container HOME");
            return;
        }
    }
    strlcpy(parent, actual, sizeof(parent));
    char *slash = strrchr(parent, '/');
    if (!slash || !slash[1]) return;
    *slash = '\0';
    const char suffix[] = "/Data/Application";
    size_t length = strlen(parent);
    if (length < sizeof(suffix)-1 || strcmp(parent+length-(sizeof(suffix)-1), suffix)) {
        snprintf(storageStatus, sizeof(storageStatus), "Nonstandard guest HOME; writes disabled");
        return;
    }
    int homeFD = open(actual, O_RDONLY | O_DIRECTORY | O_NOFOLLOW);
    if (homeFD < 0) { snprintf(storageStatus, sizeof(storageStatus), "Guest HOME open failed (%d)", errno); return; }
    if (mkdirat(homeFD, "Documents", 0700) < 0 && errno != EEXIST) {
        snprintf(storageStatus, sizeof(storageStatus), "Documents creation failed (%d)", errno);
        close(homeFD); return;
    }
    storageFD = openat(homeFD, "Documents", O_RDONLY | O_DIRECTORY | O_NOFOLLOW);
    close(homeFD);
    if (storageFD < 0) { snprintf(storageStatus, sizeof(storageStatus), "Documents open failed (%d)", errno); return; }
    snprintf(storageStatus, sizeof(storageStatus), "Guest Documents opened");
    mark("00 main entered; guest Documents validated");
}
static NSInteger loadCounter(void) {
    if (storageFD < 0) return 0;
    int fd = openat(storageFD, "BloomBoxDevProbeV4.counter", O_RDONLY | O_NOFOLLOW | O_NONBLOCK);
    if (fd < 0) return 0;
    struct stat st; char value[32] = {0};
    ssize_t n = (fstat(fd, &st) == 0 && S_ISREG(st.st_mode) && st.st_nlink == 1) ? read(fd, value, sizeof(value)-1) : -1;
    close(fd);
    if (n <= 0) return 0;
    long long v = strtoll(value, NULL, 10);
    return v >= 0 && v < NSIntegerMax ? (NSInteger)v : 0;
}
static BOOL storeCounter(NSInteger count) {
    if (storageFD < 0) return NO;
    // A fresh temporary file avoids modifying any preexisting redirected file.
    const char *tmp = "BloomBoxDevProbeV4.counter.tmp";
    int fd = openat(storageFD, tmp, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600);
    if (fd < 0) return NO;
    char value[32]; int n = snprintf(value, sizeof(value), "%ld", (long)count);
    BOOL ok = n > 0 && n < (int)sizeof(value) && write(fd, value, (size_t)n) == n && fsync(fd) == 0;
    close(fd);
    if (ok) ok = renameat(storageFD, tmp, storageFD, "BloomBoxDevProbeV4.counter") == 0;
    if (!ok) unlinkat(storageFD, tmp, 0);
    return ok;
}

@interface BBDevProbeV4Controller : UIViewController
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,assign) NSInteger count;
@end
@implementation BBDevProbeV4Controller
- (void)viewDidLoad {
    [super viewDidLoad];
    mark("04 controller viewDidLoad");
    self.view.backgroundColor = [UIColor colorWithRed:0.10 green:0.07 blue:0.17 alpha:1];
    self.count = loadCounter();
    UILabel *title = [UILabel new];
    title.text = @"BloomBox Dev";
    title.font = [UIFont boldSystemFontOfSize:34];
    title.textColor = UIColor.whiteColor;
    UILabel *subtitle = [UILabel new];
    subtitle.text = @"Nested Probe 04 · UIKit + SwiftUI";
    subtitle.textColor = [UIColor colorWithRed:0.76 green:0.68 blue:0.98 alpha:1];
    self.statusLabel = [UILabel new];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textColor = UIColor.whiteColor;
    self.statusLabel.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightRegular];
    UIButton *save = [UIButton buttonWithType:UIButtonTypeSystem];
    [save setTitle:@"Guardar prueba (+1)" forState:UIControlStateNormal];
    [save setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    save.backgroundColor = [UIColor colorWithRed:0.38 green:0.22 blue:0.75 alpha:1];
    save.layer.cornerRadius = 12;
    [save.heightAnchor constraintEqualToConstant:52].active = YES;
    [save addTarget:self action:@selector(saveTest) forControlEvents:UIControlEventTouchUpInside];
    UIButton *copy = [UIButton buttonWithType:UIButtonTypeSystem];
    [copy setTitle:@"Copiar diagnóstico" forState:UIControlStateNormal];
    [copy setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [copy.heightAnchor constraintEqualToConstant:44].active = YES;
    [copy addTarget:self action:@selector(copyLog) forControlEvents:UIControlEventTouchUpInside];
    UIButton *test = [UIButton buttonWithType:UIButtonTypeSystem];
    [test setTitle:@"Probar escritorio SwiftUI" forState:UIControlStateNormal];
    [test setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    test.backgroundColor = [UIColor colorWithRed:0.24 green:0.34 blue:0.64 alpha:1];
    test.layer.cornerRadius = 12;
    [test.heightAnchor constraintEqualToConstant:52].active = YES;
    [test addTarget:self action:@selector(testSwiftUI) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title,subtitle,self.statusLabel,save,test,copy]];
    stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 18;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:26],
        [stack.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-26],
        [stack.centerYAnchor constraintEqualToAnchor:safe.centerYAnchor]
    ]];
    [self refreshStatus:@"Interfaz UIKit iniciada"];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated]; mark("05 window visible");
}
- (void)refreshStatus:(NSString *)message {
    self.statusLabel.text = [NSString stringWithFormat:@"%@\n%s\nContador: %ld", message, storageStatus, (long)self.count];
}
- (void)saveTest {
    if (self.count >= NSIntegerMax - 1) return;
    if (storeCounter(self.count + 1)) {
        self.count++; mark("06 counter saved"); [self refreshStatus:@"Guardado correcto"];
    } else { mark("06 counter write failed"); [self refreshStatus:@"No se pudo guardar"]; }
}
- (void)testSwiftUI {
    mark("07 SwiftUI test requested");
    // Use the guest bundle's exact framework path, not the host executable path.
    NSString *path = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Frameworks/BBDevSwiftUIV4.framework/BBDevSwiftUIV4"];
    static void *handle = NULL;
    if (!handle) handle = dlopen(path.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
    if (!handle) {
        mark("08 SwiftUI framework dlopen failed");
        const char *error = dlerror();
        if (error) mark(error);
        [self refreshStatus:@"No se pudo cargar SwiftUI"];
        return;
    }
    mark("08 SwiftUI framework loaded");
    void *(*makeController)(void (*)(const char *)) = (void *(*)(void (*)(const char *)))dlsym(handle, "BBDevMakeSwiftUIV4");
    if (!makeController) {
        mark("09 SwiftUI factory symbol missing");
        [self refreshStatus:@"No se encontró la interfaz SwiftUI"];
        return;
    }
    @try {
        mark("09 creating UIHostingController");
        void *retained = makeController(mark);
        if (!retained) {
            mark("10 SwiftUI factory returned nil");
            [self refreshStatus:@"SwiftUI no devolvió una ventana"];
            return;
        }
        UIViewController *hosted = (__bridge_transfer UIViewController *)retained;
        mark("10 UIHostingController created");
        hosted.navigationItem.title = @"BloomBox Dev · SwiftUI";
        hosted.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Listo" style:UIBarButtonItemStyleDone target:self action:@selector(closeSwiftUI)];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:hosted];
        nav.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:nav animated:YES completion:^{ mark("11 SwiftUI presentation completed"); }];
    } @catch (NSException *exception) {
        mark("EXCEPTION creating/presenting SwiftUI");
        mark(exception.name.UTF8String ?: "unknown exception");
        [self refreshStatus:@"Error al presentar SwiftUI"];
    }
}
- (void)closeSwiftUI {
    [self dismissViewControllerAnimated:YES completion:^{ mark("14 returned to UIKit"); }];
}
- (void)copyLog {
    NSMutableString *result = [NSMutableString stringWithFormat:@"BloomBox Dev V4\n%s\nContador: %ld\n",storageStatus,(long)self.count];
    if (storageFD >= 0) {
        int fd = openat(storageFD, "BloomBoxDevProbeV4.log", O_RDONLY | O_NOFOLLOW | O_NONBLOCK);
        if (fd >= 0) {
            struct stat st; char data[32769] = {0};
            ssize_t n = (fstat(fd, &st) == 0 && S_ISREG(st.st_mode) && st.st_nlink == 1) ? read(fd, data, sizeof(data)-1) : -1;
            close(fd);
            if (n > 0) { NSString *s = [[NSString alloc] initWithBytes:data length:(NSUInteger)n encoding:NSUTF8StringEncoding]; if (s) [result appendString:s]; }
        }
    }
    UIPasteboard.generalPasteboard.string = result;
}
@end

@interface BBDevProbeV4Scene : UIResponder <UIWindowSceneDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation BBDevProbeV4Scene
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    mark("03 scene connecting");
    if (![scene isKindOfClass:UIWindowScene.class]) return;
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = [BBDevProbeV4Controller new];
    [self.window makeKeyAndVisible];
}
@end
@interface BBDevProbeV4Delegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation BBDevProbeV4Delegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    mark("02 app delegate launched");
    // Fallback for hosts which do not activate the scene manifest.
    if (![[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIApplicationSceneManifest"]) {
        self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        self.window.rootViewController = [BBDevProbeV4Controller new];
        [self.window makeKeyAndVisible];
    }
    return YES;
}
- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    UISceneConfiguration *configuration = [[UISceneConfiguration alloc] initWithName:@"Probe" sessionRole:session.role];
    configuration.delegateClass = BBDevProbeV4Scene.class;
    return configuration;
}
@end
int main(int argc, char *argv[]) {
    mark("00 main entered");
    prepareStorage();
    @autoreleasepool {
        @try {
            mark("01 calling UIApplicationMain");
            int result = UIApplicationMain(argc, argv, nil, NSStringFromClass(BBDevProbeV4Delegate.class));
            mark("UIApplicationMain returned");
            return result;
        } @catch (NSException *exception) {
            mark("EXCEPTION in UIApplicationMain");
            mark(exception.name.UTF8String ?: "unknown exception");
            return 1;
        }
    }
}
