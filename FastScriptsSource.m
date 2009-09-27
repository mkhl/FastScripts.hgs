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
NSString *const kFSAppNameKey = @"FastScriptsAppName";

#pragma mark HGSResult Type
NSString *const kFSResultType = HGS_SUBTYPE(kHGSTypeScript, @"fastscripts");

#pragma mark Static Data
static NSString *const kFSBundleIdentifier = @"com.red-sweater.FastScripts";
static NSString *const kFSURIFormat = @"FastScripts://FastScripts/%@";
static NSString *const kFSInvokeAction
  = @"org.purl.net.mkhl.FastScripts.action.invoke";

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
  if (self) {
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
  for (FastScriptsScriptItem *script in [[app scriptItems] get]) {
    [self indexScriptItem:script];
  FastScriptsApplication *app
    = [SBApplication applicationWithBundleIdentifier:kFSBundleIdentifier];
  }
  [self recacheContentsAfterDelay:60.0];
}

- (void)recacheContentsAfterDelay:(NSTimeInterval)delay
{
  SEL action = @selector(recacheContents);
  [self performSelector:action withObject:nil afterDelay:delay];
}

#pragma mark Result Generation
- (NSArray *)pathComponentsForScriptItem:(FastScriptsScriptItem *)script
{
  NSMutableArray *components = [NSMutableArray arrayWithObject:[script name]];
  FastScriptsScriptLibrary *parent = [[script parentLibrary] get];
  while (parent) {
    NSString *name = [parent name];
    parent = [[parent parentLibrary] get];
    if (parent) {
      [components insertObject:name atIndex:0];
    }
  }
  return components;
}

- (void)indexScriptItem:(FastScriptsScriptItem *)script
{
  NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
  [attrs setObject:script forKey:kFSScriptItemKey];
  NSArray *pathComponents = [self pathComponentsForScriptItem:script];
  NSString *name = [script name];
  NSString *path = [NSString pathWithComponents:pathComponents];
  NSString *uri = [NSString stringWithFormat:kFSURIFormat,
                   [path stringByAddingPercentEscapesUsingEncoding:
                    NSUTF8StringEncoding]];
  NSString *snip = [path stringByDeletingLastPathComponent];
  [attrs setObject:snip forKey:kHGSObjectAttributeSnippetKey];
  if ([pathComponents count] > 2) {
    if ([[pathComponents objectAtIndex:0] isEqualToString:@"Applications"]) {
      [attrs setObject:[pathComponents objectAtIndex:1] forKey:kFSAppNameKey];
    }
  }
  NSURL *file = [script scriptFile];
  NSImage *icon = appIcon_;
  if (file)
    icon = [[NSWorkspace sharedWorkspace] iconForFile:[file path]];
  [attrs setObject:icon forKey:kHGSObjectAttributeIconKey];
  HGSAction *action = [[HGSExtensionPoint actionsPoint]
                       extensionWithIdentifier:kFSInvokeAction];
  [attrs setObject:action forKey:kHGSObjectAttributeDefaultActionKey];
  HGSResult *result = [HGSResult resultWithURI:uri
                                         name:name
                                         type:kFSResultType
                                       source:self
                                   attributes:attrs];
  [self indexResult:result];
}

#pragma mark Result Filtering
- (BOOL)isResult:(HGSResult *)result
     validForApp:(NSString *)otherApp
           orNil:(BOOL)nilOK
{
  NSString *scriptApp = [result valueForKey:kFSAppNameKey];
  if (scriptApp == nil)
    return nilOK;
  return [scriptApp caseInsensitiveCompare:otherApp] == NSOrderedSame;
}

- (HGSResult *)preFilterResult:(HGSMutableResult *)result
               matchesForQuery:(HGSQuery *)query
                   pivotObject:(HGSResult *)pivotObject
{
  BOOL valid = NO;
  if (pivotObject == nil) {
    NSDictionary *activeApp = [[NSWorkspace sharedWorkspace] activeApplication];
    NSString *appName = [activeApp objectForKey:@"NSApplicationName"];
    valid = [self isResult:result validForApp:appName orNil:YES];
  } else {
    NSString *appName = [pivotObject displayName];
    valid = [self isResult:result validForApp:appName orNil:NO];
  }
  return valid ? result : nil;
}

@end
