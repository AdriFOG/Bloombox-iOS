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

// Do not initialize LiveContainer, SwiftUI, preferences or app groups here.
// All writes are restricted to the selected guest's ordinary Documents folder.
static int storageFD = -1;
static char storageStatus[160] = "Guest storage not checked";
static void mark(const char *message) {
    fprintf(stderr, "[BloomBoxDevV3] %s\n", message);
    if (storageFD < 0) return;
    int fd = openat(storageFD, "BloomBoxDevProbeV3.log", O_WRONLY | O_CREAT | O_APPEND | O_NOFOLLOW | O_NONBLOCK, 0600);
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
    mark("01 main entered; guest Documents validated");
}
static NSInteger loadCounter(void) {
    if (storageFD < 0) return 0;
    int fd = openat(storageFD, "BloomBoxDevProbeV3.counter", O_RDONLY | O_NOFOLLOW | O_NONBLOCK);
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
    const char *tmp = "BloomBoxDevProbeV3.counter.tmp";
    int fd = openat(storageFD, tmp, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600);
    if (fd < 0) return NO;
    char value[32]; int n = snprintf(value, sizeof(value), "%ld", (long)count);
    BOOL ok = n > 0 && n < (int)sizeof(value) && write(fd, value, (size_t)n) == n && fsync(fd) == 0;
    close(fd);
    if (ok) ok = renameat(storageFD, tmp, storageFD, "BloomBoxDevProbeV3.counter") == 0;
    if (!ok) unlinkat(storageFD, tmp, 0);
    return ok;
}

@interface BBDevProbeV3Controller : UIViewController
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,assign) NSInteger count;
@end
@implementation BBDevProbeV3Controller
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
    subtitle.text = @"Nested Probe 03 · UIKit";
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
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title,subtitle,self.statusLabel,save,copy]];
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
- (void)copyLog {
    NSMutableString *result = [NSMutableString stringWithFormat:@"BloomBox Dev V3\n%s\nContador: %ld\n",storageStatus,(long)self.count];
    if (storageFD >= 0) {
        int fd = openat(storageFD, "BloomBoxDevProbeV3.log", O_RDONLY | O_NOFOLLOW | O_NONBLOCK);
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

@interface BBDevProbeV3Scene : UIResponder <UIWindowSceneDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation BBDevProbeV3Scene
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    mark("03 scene connecting");
    if (![scene isKindOfClass:UIWindowScene.class]) return;
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = [BBDevProbeV3Controller new];
    [self.window makeKeyAndVisible];
}
@end
@interface BBDevProbeV3Delegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation BBDevProbeV3Delegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    mark("02 app delegate launched");
    // Fallback for hosts which do not activate the scene manifest.
    if (![[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIApplicationSceneManifest"]) {
        self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        self.window.rootViewController = [BBDevProbeV3Controller new];
        [self.window makeKeyAndVisible];
    }
    return YES;
}
- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    UISceneConfiguration *configuration = [[UISceneConfiguration alloc] initWithName:@"Probe" sessionRole:session.role];
    configuration.delegateClass = BBDevProbeV3Scene.class;
    return configuration;
}
@end
int main(int argc, char *argv[]) {
    mark("00 main entered");
    prepareStorage();
    @autoreleasepool {
        @try {
            mark("01 calling UIApplicationMain");
            int result = UIApplicationMain(argc, argv, nil, NSStringFromClass(BBDevProbeV3Delegate.class));
            mark("UIApplicationMain returned");
            return result;
        } @catch (NSException *exception) {
            mark("EXCEPTION in UIApplicationMain");
            mark(exception.name.UTF8String ?: "unknown exception");
            return 1;
        }
    }
}
