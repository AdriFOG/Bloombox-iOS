// BloomBox -> MediaBloom secondary volume HUD (opt-in per game).
// This is NOT an iOS volume HUD replacement. The physical buttons continue
// controlling the original device output volume. We only observe its changes
// with public AVAudioSession.outputVolume KVO and display an extra control
// inside BloomBox's own foreground guest scene.
//
// MediaBloom v1.0+ reads the same App Group keys in its running guest:
//   MediaBloomAudioGainV1.com.google.ios.youtubemusic
//   MediaBloomAudioGainV1.com.google.ios.youtube
//
// Implementation is kept in LCBootstrap's guest process, not in SideStore,
// not in the primary BloomBox host, and not inside the guest IPA on disk.
// No replacement of native volume controls, private notifications, or key-window
// takeover. First version targets YouTube Music and YouTube; may be expanded
// when MediaBloom exports a broader 'currently playing' guest identity.

#include <math.h>

static NSString * const BBHUDYTMusicID = @"com.google.ios.youtubemusic";
static NSString * const BBHUDYouTubeID = @"com.google.ios.youtube";
static NSString * const BBHUDTargetPref = @"BloomBoxMediaVolumeHUDTargetV1";
static const CGFloat BBHUDWidth = 298.0;
static const CGFloat BBHUDHeight = 130.0;
static NSInteger BBHUDDismissRevision = 0;

@class BBHUDVolumeViewController;
static UIWindow *BBHUDWindow;
static BBHUDVolumeViewController *BBHUDController;
static NSObject *BBHUDOutputObserver;
static NSObject *BBHUDObservedSession;
static char BBHUDKVOContext;

static void BBHUDShow(void);
static void BBHUDHideAfterDelay(NSTimeInterval delay);

@interface BBHUDNonKeyWindow : UIWindow
@end

@implementation BBHUDNonKeyWindow
// The window covers only its tiny control; the game receives the rest.
- (BOOL)canBecomeKeyWindow { return NO; }
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden) return nil;
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self || hit == self.rootViewController.view) return nil;
    return hit;
}
@end

@interface BBHUDVolumeViewController : UIViewController
@property(nonatomic, strong) UILabel *heading;
@property(nonatomic, strong) UILabel *percent;
@property(nonatomic, strong) UISlider *slider;
@property(nonatomic, strong) UISegmentedControl *source;
@property(nonatomic, strong) UIButton *mute;
@property(nonatomic, assign) float lastNonZero;
@end

@implementation BBHUDVolumeViewController
- (NSString *)currentID {
    return self.source.selectedSegmentIndex == 1 ? BBHUDYouTubeID : BBHUDYTMusicID;
}
- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:CGRectMake(0, 0, BBHUDWidth, BBHUDHeight)];
    root.backgroundColor = [UIColor colorWithRed:0.10 green:0.095 blue:0.15 alpha:0.95];
    root.layer.cornerRadius = 20;
    root.layer.borderWidth = 0.7;
    root.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.17].CGColor;
    root.clipsToBounds = YES;
    self.view = root;

    UIColor *purple = [UIColor colorWithRed:0.55 green:0.38 blue:0.91 alpha:1];
    self.heading = [[UILabel alloc] initWithFrame:CGRectMake(14, 8, 170, 25)];
    self.heading.text = @"MediaBloom";
    self.heading.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    self.heading.textColor = UIColor.whiteColor;
    [root addSubview:self.heading];

    self.percent = [[UILabel alloc] initWithFrame:CGRectMake(BBHUDWidth - 63, 8, 49, 25)];
    self.percent.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
    self.percent.textColor = [UIColor colorWithWhite:1 alpha:0.88];
    self.percent.textAlignment = NSTextAlignmentRight;
    [root addSubview:self.percent];

    self.source = [[UISegmentedControl alloc] initWithItems:@[@"Music", @"Video"]];
    self.source.frame = CGRectMake(14, 39, BBHUDWidth - 28, 29);
    self.source.selectedSegmentTintColor = purple;
    NSDictionary *labelStyle = @{NSForegroundColorAttributeName: UIColor.whiteColor};
    [self.source setTitleTextAttributes:labelStyle forState:UIControlStateSelected];
    [self.source setTitleTextAttributes:labelStyle forState:UIControlStateNormal];
    NSString *saved = [lcSharedDefaults stringForKey:BBHUDTargetPref];
    self.source.selectedSegmentIndex = [saved isEqualToString:BBHUDYouTubeID] ? 1 : 0;
    [self.source addTarget:self action:@selector(sourceChanged:) forControlEvents:UIControlEventValueChanged];
    [root addSubview:self.source];

    self.slider = [[UISlider alloc] initWithFrame:CGRectMake(14, 83, BBHUDWidth - 77, 32)];
    self.slider.minimumValue = 0;
    self.slider.maximumValue = 1;
    self.slider.minimumTrackTintColor = purple;
    self.slider.thumbTintColor = UIColor.whiteColor;
    self.slider.continuous = YES;
    [self.slider addTarget:self action:@selector(gainChanged:) forControlEvents:UIControlEventValueChanged];
    [self.slider addTarget:self action:@selector(editingBegan:) forControlEvents:UIControlEventTouchDown];
    [root addSubview:self.slider];

    self.mute = [UIButton buttonWithType:UIButtonTypeSystem];
    self.mute.frame = CGRectMake(BBHUDWidth - 53, 79, 39, 40);
    self.mute.tintColor = UIColor.whiteColor;
    self.mute.accessibilityLabel = @"Silenciar o restaurar MediaBloom";
    [self.mute addTarget:self action:@selector(toggleMute:) forControlEvents:UIControlEventTouchUpInside];
    [root addSubview:self.mute];

    self.lastNonZero = 1;
    [self readCurrentGain];
}
- (void)refreshAppearance {
    float gain = self.slider.value;
    self.percent.text = [NSString stringWithFormat:@"%d%%", (int)roundf(gain * 100)];
    [self.mute setImage:[UIImage systemImageNamed:(gain < 0.001f ?
        @"speaker.slash.fill" : @"speaker.wave.2.fill")] forState:UIControlStateNormal];
    self.slider.accessibilityLabel = [NSString stringWithFormat:@"MediaBloom %@",
        self.source.selectedSegmentIndex == 1 ? @"Video" : @"Music"];
    self.slider.accessibilityValue = self.percent.text;
}
- (void)readCurrentGain {
    NSString *key = [@"MediaBloomAudioGainV1." stringByAppendingString:self.currentID];
    id saved = [lcSharedDefaults objectForKey:key];
    float value = [saved respondsToSelector:@selector(floatValue)] ?
        [saved floatValue] : 1.0f;
    if (!isfinite(value)) value = 1.0f;
    self.slider.value = fmaxf(0, fminf(1, value));
    if (self.slider.value > 0.001f) self.lastNonZero = self.slider.value;
    [self refreshAppearance];
}
- (void)writeGain:(float)gain {
    if (!lcSharedDefaults) return;
    float bounded = isfinite(gain) ? fmaxf(0, fminf(1, gain)) : 1.0f;
    NSString *key = [@"MediaBloomAudioGainV1." stringByAppendingString:self.currentID];
    [lcSharedDefaults setFloat:bounded forKey:key];
    // App Groups propagate asynchronously to the other independent process;
    // synchronize makes the setting visible sooner, but may still lag when
    // MediaBloom is suspended (it cannot be forced to run by this overlay).
    [lcSharedDefaults synchronize];
    self.slider.value = bounded;
    if (bounded > 0.001f) self.lastNonZero = bounded;
    [self refreshAppearance];
    BBHUDHideAfterDelay(5);
}
- (void)editingBegan:(UISlider *)sender {
    // Keep it visible during interaction and while selecting a source.
    BBHUDHideAfterDelay(7);
}
- (void)gainChanged:(UISlider *)sender {
    [self writeGain:sender.value];
}
- (void)sourceChanged:(UISegmentedControl *)sender {
    [lcSharedDefaults setObject:self.currentID forKey:BBHUDTargetPref];
    [self readCurrentGain];
    BBHUDHideAfterDelay(5);
}
- (void)toggleMute:(UIButton *)sender {
    [self writeGain:self.slider.value > 0.001f ? 0.0f :
        fmaxf(0.05f, self.lastNonZero)];
}
@end

@interface BBHUDVolumeObserver : NSObject
@property(nonatomic, assign) float lastOutputVolume;
@end
@implementation BBHUDVolumeObserver
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    if (context != &BBHUDKVOContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    id raw = change[NSKeyValueChangeNewKey];
    if (![raw respondsToSelector:@selector(floatValue)]) return;
    float newVolume = [raw floatValue];
    if (!isfinite(newVolume) || fabsf(newVolume - self.lastOutputVolume) < 0.0005f) return;
    self.lastOutputVolume = newVolume;
    // We do not distinguish hardware buttons from Control Center changes.
    // Either should bring up our *additional*, not replacement, control.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive)
            BBHUDShow();
    });
}
@end

static UIWindowScene *BBHUDActiveScene(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:UIWindowScene.class] &&
                scene.activationState == UISceneActivationStateForegroundActive)
                return (UIWindowScene *)scene;
        }
    }
    return nil;
}

static void BBHUDHideAfterDelay(NSTimeInterval seconds) {
    NSInteger revision = ++BBHUDDismissRevision;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (BBHUDDismissRevision == revision && BBHUDWindow)
            BBHUDWindow.hidden = YES;
    });
}
static void BBHUDShow(void) {
    if (![NSThread isMainThread] || !BBAudioMixEnabledForCurrentGuest()) return;
    UIWindowScene *scene = BBHUDActiveScene();
    if (!scene) return;
    if (!BBHUDWindow) {
        BBHUDController = [BBHUDVolumeViewController new];
        BBHUDWindow = [[BBHUDNonKeyWindow alloc] initWithWindowScene:scene];
        BBHUDWindow.rootViewController = BBHUDController;
        BBHUDWindow.backgroundColor = UIColor.clearColor;
        BBHUDWindow.windowLevel = UIWindowLevelNormal + 90;
        BBHUDWindow.accessibilityIdentifier = @"bloombox.media.additional-volume";
    } else if (BBHUDWindow.windowScene != scene) {
        BBHUDWindow.windowScene = scene;
    }
    CGRect screen = scene.coordinateSpace.bounds;
    if (CGRectGetWidth(screen) < BBHUDWidth + 24 ||
        CGRectGetHeight(screen) < BBHUDHeight + 80) return;
    CGFloat top = 34;
    if (@available(iOS 13.0,*)) top = fmaxf(34, scene.windows.firstObject.safeAreaInsets.top + 14);
    BBHUDWindow.frame = CGRectMake(
        CGRectGetWidth(screen) - BBHUDWidth - 12, top, BBHUDWidth, BBHUDHeight);
    [BBHUDController readCurrentGain];
    // Intentionally do NOT call makeKeyAndVisible: that would steal focus.
    BBHUDWindow.hidden = NO;
    BBHUDHideAfterDelay(4);
}

static void BBHUDInstallForGuestIfEnabled(void) {
    if (!BBAudioMixEnabledForCurrentGuest()) return;
    if (BBHUDOutputObserver) return;
    // This setup must not activate or change the guest audio session.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (BBHUDOutputObserver || !BBAudioMixEnabledForCurrentGuest()) return;
        Class sessionClass = NSClassFromString(@"AVAudioSession");
        if (!sessionClass) return;
        id session = ((id(*)(id,SEL))objc_msgSend)(
            sessionClass, @selector(sharedInstance));
        if (!session) return;
        BBHUDVolumeObserver *observer = [BBHUDVolumeObserver new];
        NSNumber *current = [session valueForKey:@"outputVolume"];
        observer.lastOutputVolume = [current respondsToSelector:@selector(floatValue)] ?
            current.floatValue : 0;
        [session addObserver:observer forKeyPath:@"outputVolume"
                    options:NSKeyValueObservingOptionNew context:&BBHUDKVOContext];
        BBHUDOutputObserver = observer;
        BBHUDObservedSession = session;
        NSLog(@"[BloomBox Media HUD] Observing outputVolume for %@", lcGuestAppId);
    });
}
