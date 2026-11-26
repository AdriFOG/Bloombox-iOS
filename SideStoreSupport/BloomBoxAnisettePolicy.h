#import <Foundation/Foundation.h>

static NSString * const BBAnisetteMacServer = @"https://mac-ani.jkcoxson.com";
static NSString * const BBAnisetteSyncKey = @"BloomBoxAnisetteAutoSyncV1";

static NSString *BBAnisetteHeader(NSDictionary *headers, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        id raw = headers[key];
        if (![raw isKindOfClass:NSString.class]) continue;
        NSString *value = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (value.length == 0 || value.length > 1024 ||
            [value rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location != NSNotFound) continue;
        return value;
    }
    return nil;
}

// Only public client metadata. Never import server-supplied device identifiers,
// serials, tokens, ADI, credentials or certificate data.
static NSDictionary<NSString *, NSString *> *BBAnisetteOverrides(id json) {
    if (![json isKindOfClass:NSDictionary.class]) return nil;
    NSString *client = BBAnisetteHeader(json, @[@"client_info", @"clientInfo", @"X-Mme-Client-Info"]);
    NSString *agent = BBAnisetteHeader(json, @[@"user_agent", @"userAgent", @"User-Agent"]);
    if (!client || !agent) return nil;
    NSMutableDictionary *result = [@{@"customAnisetteClientInfo":client, @"customAnisetteUserAgent":agent} mutableCopy];
    NSString *xcode = BBAnisetteHeader(json, @[@"custom_xcode_version", @"customXcodeVersion", @"X-Xcode-Version", @"xcodeVersion"]);
    if (xcode) result[@"customAnisetteXcodeVersion"] = xcode;
    return result;
}

static BOOL BBAnisetteCatalogContainsMacServer(id json) {
    if ([json isKindOfClass:NSDictionary.class]) json = json[@"servers"];
    if (![json isKindOfClass:NSArray.class]) return NO;
    for (id entry in json) {
        if (![entry isKindOfClass:NSDictionary.class]) continue;
        if (![entry[@"address"] isKindOfClass:NSString.class]) continue;
        id hidden = entry[@"isHidden"];
        if (hidden && (![hidden isKindOfClass:NSNumber.class] || [hidden boolValue])) continue;
        if ([entry[@"address"] isEqualToString:BBAnisetteMacServer]) return YES;
    }
    return NO;
}

// Automatically migrate only installer defaults, never a user's customized
// working setup. This policy is also called only on the login controller.
static BOOL BBAnisetteShouldAutoSync(NSDictionary *prefs, BOOL seeded) {
    if (!seeded || [prefs[BBAnisetteSyncKey] boolValue] ||
        [prefs[@"AnisetteServersManager.isOfflineMode"] boolValue] ||
        [prefs[@"isAnisetteOfflineMode"] boolValue]) return NO;
    NSString *server = prefs[@"menuAnisetteURL"];
    NSString *client = prefs[@"customAnisetteClientInfo"];
    NSString *agent = prefs[@"customAnisetteUserAgent"];
    if (server && ![server isKindOfClass:NSString.class]) return NO;
    if (client && ![client isKindOfClass:NSString.class]) return NO;
    if (agent && ![agent isKindOfClass:NSString.class]) return NO;
    if ([server isEqualToString:BBAnisetteMacServer]) return NO;
    BOOL previousPreview = [server isEqualToString:@"https://new.ani.sidestore.io"] &&
        [client isEqualToString:@"<MacBookPro18,3> <Mac OS X;26.6;25F84> <com.apple.AuthKit/1 (com.apple.akd/1.0)>"] &&
        [agent isEqualToString:@"AuthKit/1 (Macintosh; OS X 26.6) (com.apple.akd/1.0)"] &&
        [prefs[@"useOnDeviceAnisette"] isEqual:@NO];
    BOOL defaultServer = server.length == 0 || [server isEqualToString:@"https://ani.sidestore.io"] ||
        [server isEqualToString:@"https://new.ani.sidestore.io"];
    return previousPreview || (defaultServer && client.length == 0 && agent.length == 0);
}
