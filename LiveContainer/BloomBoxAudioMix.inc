// BloomBox simultaneous-audio experiment (per guest, OFF by default).
// Included by LCBootstrap.m and built ONLY in BloomBox's native guest loader.
// It does not touch the global iPhone volume, capture/redirect audio, change
// MediaBloom, or alter game bundle files. Per-app preferences are in the
// authorized LiveContainer App Group.
//
// Opt-in policy: convert SoloAmbient -> Ambient; add MixWithOthers to Playback,
// PlayAndRecord, and MultiRoute. Preserve existing modes and supported options,
// but drop ducking and spoken-audio interruption flags: neither should pause
// or lower a user's music. Unsupported categories/route policies are untouched.
//
// Uses dynamic Objective-C runtime calls instead of linking AVFAudio at build
// time. This allows the already-pinned LiveContainer Xcode target to compile.
#include <objc/message.h>

static const NSUInteger BBAudioMixWithOthers = (1U << 0);
static const NSUInteger BBAudioDuckOthers = (1U << 1);
static const NSUInteger BBAudioInterruptSpokenAudio = (1U << 4);
static NSString * const BBAudioPlaybackCategory = @"AVAudioSessionCategoryPlayback";
static NSString * const BBAudioPlayAndRecordCategory = @"AVAudioSessionCategoryPlayAndRecord";
static NSString * const BBAudioMultiRouteCategory = @"AVAudioSessionCategoryMultiRoute";
static NSString * const BBAudioSoloAmbientCategory = @"AVAudioSessionCategorySoloAmbient";
static NSString * const BBAudioAmbientCategory = @"AVAudioSessionCategoryAmbient";

static IMP BBAudioOrigSetCategory = NULL;
static IMP BBAudioOrigSetCategoryOptions = NULL;
static IMP BBAudioOrigSetCategoryModeOptions = NULL;
static IMP BBAudioOrigSetCategoryModePolicyOptions = NULL;
static BOOL BBAudioMixHooksInstalled = NO;

static BOOL BBAudioMixEnabledForCurrentGuest(void) {
    // The built-in SideStore and the normal BloomBox host must not be hooked.
    if (isSideStore || !lcSharedDefaults || lcGuestAppId.length == 0) return NO;
    NSString *bundleID = [lcGuestAppId
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].lowercaseString;
    if (bundleID.length == 0) return NO;
    NSString *key = [@"BloomBoxAudioMixEnabledV1." stringByAppendingString:bundleID];
    return [lcSharedDefaults boolForKey:key];
}

static BOOL BBAudioCategoryCanMix(NSString *category) {
    return [category isEqualToString:BBAudioPlaybackCategory] ||
           [category isEqualToString:BBAudioPlayAndRecordCategory] ||
           [category isEqualToString:BBAudioMultiRouteCategory];
}

static NSString *BBAudioMixedCategory(NSString *category) {
    if ([category isEqualToString:BBAudioSoloAmbientCategory]) return BBAudioAmbientCategory;
    return category;
}

static NSUInteger BBAudioMixedOptions(NSString *category, NSUInteger options) {
    if (BBAudioCategoryCanMix(category)) {
        return (options | BBAudioMixWithOthers) &
               ~(BBAudioDuckOthers | BBAudioInterruptSpokenAudio);
    }
    // Ambient mixes without specifying the bit; preserving unsupported
    // category options avoids invalid-parameter errors.
    return options;
}

static BOOL BBAudioHookCategory(id obj, SEL cmd, NSString *category, NSError **error) {
    if (!BBAudioMixEnabledForCurrentGuest()) {
        return ((BOOL(*)(id,SEL,NSString*,NSError**))BBAudioOrigSetCategory)(obj,cmd,category,error);
    }
    NSString *effective = BBAudioMixedCategory(category);
    if (BBAudioCategoryCanMix(effective) && BBAudioOrigSetCategoryOptions) {
        return ((BOOL(*)(id,SEL,NSString*,NSUInteger,NSError**))BBAudioOrigSetCategoryOptions)(
            obj, @selector(setCategory:withOptions:error:), effective, BBAudioMixWithOthers, error);
    }
    return ((BOOL(*)(id,SEL,NSString*,NSError**))BBAudioOrigSetCategory)(
        obj,cmd,effective,error);
}

static BOOL BBAudioHookCategoryOptions(id obj, SEL cmd, NSString *category,
                                        NSUInteger options, NSError **error) {
    if (BBAudioMixEnabledForCurrentGuest()) {
        NSString *effective = BBAudioMixedCategory(category);
        options = BBAudioMixedOptions(effective, options);
        category = effective;
    }
    return ((BOOL(*)(id,SEL,NSString*,NSUInteger,NSError**))BBAudioOrigSetCategoryOptions)(
        obj,cmd,category,options,error);
}

static BOOL BBAudioHookCategoryModeOptions(id obj, SEL cmd, NSString *category,
                                            NSString *mode, NSUInteger options,
                                            NSError **error) {
    if (BBAudioMixEnabledForCurrentGuest()) {
        NSString *effective = BBAudioMixedCategory(category);
        options = BBAudioMixedOptions(effective, options);
        category = effective;
    }
    return ((BOOL(*)(id,SEL,NSString*,NSString*,NSUInteger,NSError**))BBAudioOrigSetCategoryModeOptions)(
        obj,cmd,category,mode,options,error);
}

static BOOL BBAudioHookCategoryModePolicyOptions(id obj, SEL cmd, NSString *category,
                                                  NSString *mode, NSUInteger policy,
                                                  NSUInteger options, NSError **error) {
    // Apple's mix option applies only with the default routing policy.
    // Leave advanced AirPlay/long-form policies exactly as the guest chose.
    if (policy == 0 && BBAudioMixEnabledForCurrentGuest()) {
        NSString *effective = BBAudioMixedCategory(category);
        options = BBAudioMixedOptions(effective, options);
        category = effective;
    }
    return ((BOOL(*)(id,SEL,NSString*,NSString*,NSUInteger,NSUInteger,NSError**))
            BBAudioOrigSetCategoryModePolicyOptions)(
        obj,cmd,category,mode,policy,options,error);
}

static IMP BBAudioHookMethod(Class klass, SEL selector, IMP replacement) {
    if (!klass) return NULL;
    Method method = class_getInstanceMethod(klass, selector);
    return method ? method_setImplementation(method, replacement) : NULL;
}

static void BBAudioMixInstallForGuestIfEnabled(void) {
    if (!BBAudioMixEnabledForCurrentGuest()) return;
    if (BBAudioMixHooksInstalled) return;

    Class klass = NSClassFromString(@"AVAudioSession");
    if (!klass) {
        dlopen("/System/Library/Frameworks/AVFAudio.framework/AVFAudio", RTLD_LAZY);
        klass = NSClassFromString(@"AVAudioSession");
    }
    if (!klass) {
        dlopen("/System/Library/Frameworks/AVFoundation.framework/AVFoundation", RTLD_LAZY);
        klass = NSClassFromString(@"AVAudioSession");
    }
    if (!klass) {
        NSLog(@"[BloomBox Audio Mix] AVAudioSession unavailable; skipping.");
        return;
    }

    // Capture original setters before installing. Direct original IMP calls
    // avoid recursion when the guest changes audio category repeatedly.
    BBAudioOrigSetCategory = BBAudioHookMethod(klass, @selector(setCategory:error:),
        (IMP)BBAudioHookCategory);
    BBAudioOrigSetCategoryOptions = BBAudioHookMethod(klass, @selector(setCategory:withOptions:error:),
        (IMP)BBAudioHookCategoryOptions);
    BBAudioOrigSetCategoryModeOptions = BBAudioHookMethod(klass, @selector(setCategory:mode:options:error:),
        (IMP)BBAudioHookCategoryModeOptions);
    BBAudioOrigSetCategoryModePolicyOptions = BBAudioHookMethod(klass,
        @selector(setCategory:mode:routeSharingPolicy:options:error:),
        (IMP)BBAudioHookCategoryModePolicyOptions);
    BBAudioMixHooksInstalled = YES;

    // If the LC process already has an active non-mixable audio session,
    // fix it once before loading the game's executable. Never activate a
    // previously inactive session or restart the background music ourselves.
    id session = ((id(*)(id,SEL))objc_msgSend)(klass, @selector(sharedInstance));
    NSString *category = ((id(*)(id,SEL))objc_msgSend)(session, @selector(category));
    NSUInteger options = ((NSUInteger(*)(id,SEL))objc_msgSend)(
        session, @selector(categoryOptions));
    NSString *effective = BBAudioMixedCategory(category);
    if ([category isEqualToString:BBAudioSoloAmbientCategory] ||
        BBAudioCategoryCanMix(effective)) {
        NSError *error = nil;
        BOOL ok = NO;
        if (BBAudioOrigSetCategoryOptions) {
            ok = ((BOOL(*)(id,SEL,NSString*,NSUInteger,NSError**))BBAudioOrigSetCategoryOptions)(
                session, @selector(setCategory:withOptions:error:), effective,
                BBAudioMixedOptions(effective, options), &error);
        }
        if (!ok && error) {
            NSLog(@"[BloomBox Audio Mix] Cannot configure initial mix for %@: %@",
                  lcGuestAppId, error.localizedDescription);
        }
    }
    NSLog(@"[BloomBox Audio Mix] Enabled for %@; category=%@",lcGuestAppId,category);
}
