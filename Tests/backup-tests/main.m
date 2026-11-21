#import <Foundation/Foundation.h>
#import "BloomBoxArchive.h"
#include "archive.h"
#include "archive_entry.h"
static void check(BOOL value, NSString *message) { if (!value) { NSLog(@"FAIL: %@", message); exit(1); } }
static void hostile(NSURL *zip, const char *path, mode_t type, int64_t size) {
    struct archive *a = archive_write_new(); archive_write_set_format_zip(a);
    check(archive_write_open_filename(a, zip.fileSystemRepresentation) == ARCHIVE_OK, @"create fixture");
    struct archive_entry *e = archive_entry_new();
    archive_entry_set_pathname(e, path); archive_entry_set_filetype(e, type);
    archive_entry_set_perm(e, 0600); archive_entry_set_size(e, size);
    if (type == AE_IFLNK) archive_entry_set_symlink(e, "../../outside");
    archive_write_header(a, e);
    archive_entry_free(e); archive_write_close(a); archive_write_free(a);
}
static void guestIPAEntry(struct archive *writer, const char *path, NSData *content) {
    struct archive_entry *entry = archive_entry_new();
    archive_entry_set_pathname(entry, path);
    archive_entry_set_filetype(entry, AE_IFREG);
    archive_entry_set_perm(entry, 0644);
    archive_entry_set_size(entry, (la_int64_t)content.length);
    check(archive_write_header(writer, entry) == ARCHIVE_OK, @"guest IPA header");
    if (content.length) {
        check(archive_write_data(writer, content.bytes, content.length) == (la_ssize_t)content.length,
              @"guest IPA content");
    }
    archive_entry_free(entry);
}
static void guestIPAFixture(NSURL *ipa, BOOL hasExecutable, BOOL secondApp) {
    NSDictionary *info = @{
        @"CFBundleIdentifier": @"com.aigch.getMoreRam",
        @"CFBundleExecutable": @"GetMoreRam",
        @"CFBundleVersion": @"1",
        @"CFBundleShortVersionString": @"1.0"
    };
    NSError *error = nil;
    NSData *plist = [NSPropertyListSerialization dataWithPropertyList:info
                                                                format:NSPropertyListXMLFormat_v1_0
                                                               options:0 error:&error];
    check(plist != nil, error.description ?: @"guest info plist");
    struct archive *writer = archive_write_new();
    archive_write_set_format_zip(writer);
    check(archive_write_open_filename(writer, ipa.fileSystemRepresentation) == ARCHIVE_OK,
          @"create guest IPA");
    guestIPAEntry(writer, "Payload/GetMoreRam.app/Info.plist", plist);
    if (hasExecutable) {
        guestIPAEntry(writer, "Payload/GetMoreRam.app/GetMoreRam",
                      [@"binary-fixture" dataUsingEncoding:NSUTF8StringEncoding]);
    }
    if (secondApp) {
        guestIPAEntry(writer, "Payload/Other.app/Other",
                      [@"another-executable" dataUsingEncoding:NSUTF8StringEncoding]);
    }
    check(archive_write_close(writer) == ARCHIVE_OK, @"close guest IPA");
    archive_write_free(writer);
}

int main(void) { @autoreleasepool {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *root = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
    NSURL *source = [root URLByAppendingPathComponent:@"source"];
    NSError *error = nil;
    check([fm createDirectoryAtURL:[source URLByAppendingPathComponent:@"Library/Preferences"] withIntermediateDirectories:YES attributes:nil error:&error], @"mkdir");
    check([fm createDirectoryAtURL:[source URLByAppendingPathComponent:@"Documents/Empty"] withIntermediateDirectories:YES attributes:nil error:&error], @"empty directory");
    NSMutableData *large = [NSMutableData dataWithLength:5 * 1024 * 1024 + 17];
    arc4random_buf(large.mutableBytes, large.length);
    check([large writeToURL:[source URLByAppendingPathComponent:@"Documents/partida.dat"] options:0 error:&error], @"write large file");
    NSData *prefs = [@"hidden preferences / ñ / 日本語" dataUsingEncoding:NSUTF8StringEncoding];
    check([prefs writeToURL:[source URLByAppendingPathComponent:@"Library/Preferences/.ajustes"] options:0 error:&error], @"write hidden file");
    NSURL *zip = [root URLByAppendingPathComponent:@"backup.zip"];
    check([BloomBoxArchive packDirectory:source toURL:zip error:&error], error.description);
    NSURL *output = [root URLByAppendingPathComponent:@"restored"];
    check([BloomBoxArchive unpackFile:zip toURL:output error:&error], error.description);
    check([[NSData dataWithContentsOfURL:[output URLByAppendingPathComponent:@"Documents/partida.dat"]] isEqual:large], @"streamed data roundtrip");
    check([[NSData dataWithContentsOfURL:[output URLByAppendingPathComponent:@"Library/Preferences/.ajustes"]] isEqual:prefs], @"hidden data roundtrip");
    check([fm fileExistsAtPath:[output URLByAppendingPathComponent:@"Documents/Empty"].path], @"empty folder roundtrip");
    check(![BloomBoxArchive unpackFile:zip toURL:output error:&error], @"reject existing target");
    NSArray *paths = @[@"../escape", @"/absolute", @"safe/../../escape", @"back\\..\\..\\escape"];
    for (NSString *path in paths) {
        NSURL *bad = [root URLByAppendingPathComponent:@"bad.zip"];
        // libarchive may normalize ZIP backslashes to slashes. Test traversal through both forms.
        hostile(bad, path.UTF8String, AE_IFREG, 0);
        NSURL *dest = [root URLByAppendingPathComponent:@"rejected"];
        check(![BloomBoxArchive unpackFile:bad toURL:dest error:&error], @"reject unsafe path");
        check(![fm fileExistsAtPath:dest.path], @"cleanup rejected archive");
    }
    NSURL *bad = [root URLByAppendingPathComponent:@"bad.zip"];
    hostile(bad, "link", AE_IFLNK, 0);
    check(![BloomBoxArchive unpackFile:bad toURL:[root URLByAppendingPathComponent:@"link-output"] error:&error], @"reject imported symlink");
    NSData *bytes = [NSData dataWithContentsOfURL:zip];
    [[bytes subdataWithRange:NSMakeRange(0, bytes.length / 2)] writeToURL:bad atomically:YES];
    check(![BloomBoxArchive unpackFile:bad toURL:[root URLByAppendingPathComponent:@"truncated"] error:&error], @"reject truncated data");
    check([fm createSymbolicLinkAtURL:[source URLByAppendingPathComponent:@"external"] withDestinationURL:root error:&error], @"create link fixture");
    check(![BloomBoxArchive packDirectory:source toURL:bad error:&error], @"reject source link rather than read outside data");
    check(![fm fileExistsAtPath:bad.path], @"cleanup failed export");
    check(![fm fileExistsAtPath:[root URLByAppendingPathComponent:@"escape"].path], @"no traversal write");
    // Regression: GetMoreRam is a normal guest IPA. It must not be forced
    // through the strict BloomBox/SideStore self-update validator.
    NSURL *guestURL = [root URLByAppendingPathComponent:@"GetMoreRam.ipa"];
    guestIPAFixture(guestURL, YES, NO);
    NSError *guestError = nil;
    NSDictionary *guest = [BloomBoxArchive inspectGuestIPA:guestURL error:&guestError];
    check([guest[@"bundle"] isEqualToString:@"com.aigch.getMoreRam"],
          guestError.description ?: @"guest IPA bundle");
    check([guest[@"executable"] isEqualToString:@"GetMoreRam"], @"guest executable");
    check([BloomBoxArchive inspectIPA:guestURL error:&guestError] == nil,
          @"strict BloomBox self-update inspector must still reject GetMoreRam");

    NSURL *incompleteGuest = [root URLByAppendingPathComponent:@"IncompleteGetMoreRam.ipa"];
    guestIPAFixture(incompleteGuest, NO, NO);
    check([BloomBoxArchive inspectGuestIPA:incompleteGuest error:&guestError] == nil,
          @"reject guest IPA without executable");

    NSURL *multipleGuest = [root URLByAppendingPathComponent:@"MultipleGetMoreRam.ipa"];
    guestIPAFixture(multipleGuest, YES, YES);
    check([BloomBoxArchive inspectGuestIPA:multipleGuest error:&guestError] == nil,
          @"reject guest IPA with multiple apps");
    NSURL *unsafeGuest = [root URLByAppendingPathComponent:@"UnsafeGetMoreRam.ipa"];
    hostile(unsafeGuest, "../escape", AE_IFREG, 0);
    check([BloomBoxArchive inspectGuestIPA:unsafeGuest error:&guestError] == nil,
          @"reject traversal in guest IPA");

    [fm removeItemAtURL:root error:nil];
    NSLog(@"PASS: backups + guest IPA accepts GetMoreRam safely without weakening strict BloomBox host checks");
    return 0;
} }
