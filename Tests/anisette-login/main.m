#import "../../SideStoreSupport/BloomBoxAnisettePolicy.h"
#include <assert.h>
int main(void) {
    @autoreleasepool {
        NSDictionary *headers = @{@"client_info":@"<Mac> <Mac OS X;26.6;25F84>", @"user_agent":@"AuthKit/1", @"deviceUniqueIdentifier":@"never import", @"token":@"never import"};
        NSDictionary *values = BBAnisetteOverrides(headers);
        assert(values.count == 2);
        assert([values[@"customAnisetteUserAgent"] isEqual:@"AuthKit/1"]);
        assert(!BBAnisetteOverrides(@{@"client_info":@"a"}));
        assert(!BBAnisetteOverrides(@{@"client_info":@"a\nb", @"user_agent":@"agent"}));
        assert(!BBAnisetteOverrides(@{@"client_info":@42, @"user_agent":@"agent"}));
        assert(BBAnisetteCatalogContainsMacServer(@[@{@"address":BBAnisetteMacServer, @"isHidden":@NO}]));
        assert(!BBAnisetteCatalogContainsMacServer(@[@{@"address":BBAnisetteMacServer, @"isHidden":@YES}]));
        assert(!BBAnisetteCatalogContainsMacServer(@[@{@"address":@"https://mac-ani.jkcoxson.com.evil.example"}]));
        assert(BBAnisetteShouldAutoSync(@{}, YES));
        assert(!BBAnisetteShouldAutoSync(@{}, NO));
        assert(!BBAnisetteShouldAutoSync(@{BBAnisetteSyncKey:@YES}, YES));
        assert(!BBAnisetteShouldAutoSync(@{@"menuAnisetteURL":BBAnisetteMacServer}, YES));
        assert(!BBAnisetteShouldAutoSync(@{@"menuAnisetteURL":@"https://custom.example", @"customAnisetteClientInfo":@"my config"}, YES));
        assert(!BBAnisetteShouldAutoSync(@{@"isAnisetteOfflineMode":@YES}, YES));
        assert(BBAnisetteShouldAutoSync(@{@"menuAnisetteURL":@"https://new.ani.sidestore.io", @"customAnisetteClientInfo":@"<MacBookPro18,3> <Mac OS X;26.6;25F84> <com.apple.AuthKit/1 (com.apple.akd/1.0)>", @"customAnisetteUserAgent":@"AuthKit/1 (Macintosh; OS X 26.6) (com.apple.akd/1.0)", @"useOnDeviceAnisette":@NO}, YES));
        puts("PASS: Anisette metadata allowlist, catalog validation and installer-only migration.");
    }
    return 0;
}
