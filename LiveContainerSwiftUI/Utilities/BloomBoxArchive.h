#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// Streaming ZIP transport for data backups. Destinations must be fresh private directories.
@interface BloomBoxArchive : NSObject
+ (BOOL)packDirectory:(NSURL *)source toURL:(NSURL *)destination error:(NSError **)error NS_SWIFT_NAME(pack(source:destination:));
+ (BOOL)unpackFile:(NSURL *)source toURL:(NSURL *)destination error:(NSError **)error NS_SWIFT_NAME(unpack(source:destination:));
/// Read/verify IPA entries without extraction. Does not authenticate its publisher.
/// Restricted Playnite .pthm ZIP extraction for data-only theme files; no executables.
+ (BOOL)unpackPlayniteTheme:(NSURL *)source toURL:(NSURL *)destination error:(NSError **)error NS_SWIFT_NAME(unpackPlayniteTheme(source:destination:));
/// Inspect a normal guest IPA without requiring BloomBox's own framework/extensions.
/// Does not authenticate the publisher; callers must verify release origin + SHA-256.
+ (nullable NSDictionary<NSString *, id> *)inspectGuestIPA:(NSURL *)source error:(NSError **)error NS_SWIFT_NAME(inspectGuestIPA(_:));
/// Strict BloomBox host-only IPA preflight for self-reinstallation.
+ (nullable NSDictionary<NSString *, id> *)inspectIPA:(NSURL *)source error:(NSError **)error NS_SWIFT_NAME(inspectIPA(_:));
+ (BOOL)validateAPK:(NSURL *)source error:(NSError **)error NS_SWIFT_NAME(validateAPK(_:));
@end
NS_ASSUME_NONNULL_END
