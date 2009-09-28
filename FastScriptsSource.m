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
- (void)indexScriptItem:(FastScriptsScriptItem *)script
   atPathWithComponents:(NSArray *)pathComponents;
- (void)indexScriptLibrary:(FastScriptsScriptLibrary *)library
      atPathWithComponents:(NSArray *)pathComponents;
- (void)indexTopLevelScriptLibrary:(FastScriptsScriptLibrary *)library;
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
  FastScriptsApplication *app
    = [SBApplication applicationWithBundleIdentifier:kFSBundleIdentifier];
  for (FastScriptsScriptLibrary *library in [app topLevelScriptLibraries]) {
    [self indexTopLevelScriptLibrary:library];
  }
  [self recacheContentsAfterDelay:60.0];
}

- (void)recacheContentsAfterDelay:(NSTimeInterval)delay
{
  SEL action = @selector(recacheContents);
  [self performSelector:action withObject:nil afterDelay:delay];
}

#pragma mark Result Generation
- (void)indexScriptItem:(FastScriptsScriptItem *)script
   atPathWithComponents:(NSArray *)pathComponents
{
  NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
  [attrs setObject:script forKey:kFSScriptItemKey];
  NSString *name = [script name];
  NSString *snip = [NSString pathWithComponents:pathComponents];
  NSString *path = [snip stringByAppendingPathComponent:name];
  NSString *uri = [NSString stringWithFormat:kFSURIFormat,
                   [path stringByAddingPercentEscapesUsingEncoding:
                    NSUTF8StringEncoding]];
  [attrs setObject:snip forKey:kHGSObjectAttributeSnippetKey];
  if ([pathComponents count] > 1) {
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

- (void)indexScriptLibrary:(FastScriptsScriptLibrary *)library
      atPathWithComponents:(NSArray *)pathComponents
{
  for (FastScriptsScriptItem *script in [library scriptItems]) {
    [self indexScriptItem:script atPathWithComponents:pathComponents];
  }
  for (FastScriptsScriptLibrary *sublibrary in [library scriptLibraries]) {
    NSString *name = [sublibrary name];
    NSArray *subpathComponents = [pathComponents arrayByAddingObject:name];
    [self indexScriptLibrary:sublibrary atPathWithComponents:subpathComponents];
  }
}

- (void)indexTopLevelScriptLibrary:(FastScriptsScriptLibrary *)library
{
  [self indexScriptLibrary:library atPathWithComponents:[NSArray array]];
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
