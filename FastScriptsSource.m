//
//  FastScriptsSource.m
//
//  Copyright (c) 2009  Martin Kuehl <purl.org/net/mkhl>
//  Licensed under the MIT License.
//

#import <Vermilion/Vermilion.h>
#import "FastScriptsBridge.h"
#import "Macros.h"

#pragma mark HGSResult Keys
NSString *const kFSScriptItemKey = @"FastScriptsScriptItem";

#pragma mark HGSResult Type
NSString *const kFSResultType = HGS_SUBTYPE(kHGSTypeScript, @"fastscripts");

#pragma mark Static Data
static NSString *const kFSBundleIdentifier = @"com.red-sweater.FastScripts";
static NSString *const kFSURIFormat = @"FastScripts://FastScripts/%@";
static NSString *const kFSInvokeAction
  = @"org.purl.net.mkhl.FastScripts.action.invoke";

static NSString *_FSScriptItemPath(FastScriptsScriptItem *script)
{
  NSMutableArray *names = [NSMutableArray arrayWithObject:[script name]];
  FastScriptsScriptLibrary *parent = [[script parentLibrary] get];
  while (parent) {
    NSString *name = [parent name];
    parent = [[parent parentLibrary] get];
    if (parent)
      [names insertObject:name atIndex:0];
  }
  return [NSString pathWithComponents:names];
}

#pragma mark -
@interface FastScriptsSource : HGSMemorySearchSource {
 @private
  NSImage *appIcon_;
}
- (void)recacheContents;
- (void)recacheContentsAfterDelay:(NSTimeInterval)delay;
- (void)indexScriptItem:(FastScriptsScriptItem *)script;
@end

#pragma mark -
@implementation FastScriptsSource

#pragma mark Memory Management
- (id)initWithConfiguration:(NSDictionary *)configuration
{
  self = [super initWithConfiguration:configuration];
  if (self == nil)
    return nil;
  NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
  NSString *bundlePath
    = [workspace absolutePathForAppBundleWithIdentifier:kFSBundleIdentifier];
  if (bundlePath == nil) {
    [self release];
    return nil;
  }
  appIcon_ = [[workspace iconForFile:bundlePath] retain];
  if ([self loadResultsCache]) {
    [self recacheContentsAfterDelay:10.0];
  } else {
    [self recacheContents];
  }
  return self;
}

- (void)dealloc
{
  DESTROY(appIcon_);
  [super dealloc];
}

#pragma mark Result Index
- (void)recacheContents
{
  [self clearResultIndex];
  FastScriptsApplication *app
    = [SBApplication applicationWithBundleIdentifier:kFSBundleIdentifier];
  for (FastScriptsScriptItem *script in [[app scriptItems] get])
    [self indexScriptItem:script];
  [self recacheContentsAfterDelay:60.0];
}

- (void)recacheContentsAfterDelay:(NSTimeInterval)delay
{
  [self performSelector:@selector(recacheContents)
             withObject:nil
             afterDelay:delay];
}

#pragma mark Result Generation
- (void)indexScriptItem:(FastScriptsScriptItem *)script
{
  NSString *path = _FSScriptItemPath(script);
  NSString *uri = [NSString stringWithFormat:kFSURIFormat,
                   [path stringByAddingPercentEscapesUsingEncoding:
                    NSUTF8StringEncoding]];
  NSString *name = [script name];
  NSString *snip = [path stringByDeletingLastPathComponent];
  HGSAction *action = [[HGSExtensionPoint actionsPoint]
                       extensionWithIdentifier:kFSInvokeAction];
  NSImage *icon = [[NSWorkspace sharedWorkspace]
                   iconForFile:[[script scriptFile] path]];
  if (icon == nil)
    icon = appIcon_;
  NSDictionary *attrs = NSDICT(script, kFSScriptItemKey,
                               snip, kHGSObjectAttributeSnippetKey,
                               icon, kHGSObjectAttributeIconKey,
                               action, kHGSObjectAttributeDefaultActionKey);
  [self indexResult:[HGSResult resultWithURI:uri
                                        name:name
                                        type:kFSResultType
                                      source:self
                                  attributes:attrs]];
}

@end
