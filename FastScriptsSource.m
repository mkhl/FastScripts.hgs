//
//  FastScriptsSource.m
//
//  Copyright (c) 2009-2010  Martin Kuehl <purl.org/net/mkhl>
//  Licensed under the MIT License.
//

#import "FastScriptsSource.h"

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

#pragma mark Helpers
static FastScriptsApplication *_FSApp(void) {
  return [SBApplication applicationWithBundleIdentifier:kFSBundleIdentifier];
}

static NSString *_FSAppPath(void) {
  NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
  return [workspace absolutePathForAppBundleWithIdentifier:kFSBundleIdentifier];
}

static NSString *_FSItemURI(NSString *name, NSString *path) {
  path = [path stringByAppendingPathComponent:name];
  return [NSString stringWithFormat:kFSURIFormat,
          [path stringByAddingPercentEscapesUsingEncoding:
           NSUTF8StringEncoding]];
}

static NSString *_FSItemApp(NSArray *pathComponents) {
  NSString *app = nil;
  if ([pathComponents count] > 1) {
    if ([[pathComponents objectAtIndex:0] isEqualToString:@"Applications"]) {
      app = [pathComponents objectAtIndex:1];
    }
  }
  return app;
}

static HGSAction *_FSItemAction(void) {
  HGSExtensionPoint *point = [HGSExtensionPoint actionsPoint];
  return [point extensionWithIdentifier:kFSInvokeAction];
}

#pragma mark -
@interface FastScriptsSource : HGSMemorySearchSource {
 @private
  NSString *appPath_;
  NSOperation *indexingOperation_;
}
- (void)reloadResultsCache;
- (void)indexScriptsForApp:(FastScriptsApplication *)application
                         operation:(NSOperation *)operation;
@end

#pragma mark -
@implementation FastScriptsSource

#pragma mark Memory Management
- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    if ((appPath_ = [_FSAppPath() retain]) == nil) {
      HGSLog(@"%@: Unable to locate FastScripts.app", self);
    }
    [self reloadResultsCache];
  }
  return self;
}

- (void)dealloc {
  [appPath_ release];
  [indexingOperation_ release];
  [super dealloc];
}

- (void)uninstall {
  [indexingOperation_ cancel];
  [super uninstall];
}

- (void)updateAppPath {
  if (appPath_ == nil) {
    appPath_ = [_FSAppPath() retain];
  }
}

#pragma mark Result Index
- (void)updateResultsCache {
  [indexingOperation_ cancel];
  [indexingOperation_ release];
  SEL update = @selector(updateResultsWithDummy:operation:);
  indexingOperation_ = [[NSInvocationOperation alloc] hgs_initWithTarget:self
                                                                selector:update
                                                                  object:nil];
  [[HGSOperationQueue sharedOperationQueue] addOperation:indexingOperation_];
}

- (void)updateResultsCacheAfterDelay:(NSTimeInterval)delay {
  [self performSelector:@selector(updateResultsCache)
             withObject:nil
             afterDelay:delay];
}

- (void)updateResultsWithDummy:(id)dummy operation:(NSOperation *)operation {
  if (![operation isCancelled]) {
    FastScriptsApplication *app = _FSApp();
    if (app) {
      [self updateAppPath];
      [self clearResultIndex];
      [self indexScriptsForApp:app operation:operation];
      if (![operation isCancelled]) {
        [self saveResultsCache];
      }
    }
    [self updateResultsCacheAfterDelay:60.0];
  }
}

- (void)reloadResultsCache {
  if ([self loadResultsCache]) {
    [self updateResultsCacheAfterDelay:10.0];
  } else {
    [self updateResultsCache];
  }
}

#pragma mark Result Generation
- (void)indexScriptItem:(FastScriptsScriptItem *)script
   atPathWithComponents:(NSArray *)pathComponents
              operation:(NSOperation *)operation {
  if (![operation isCancelled]) {
    NSString *name = [script name];
    NSString *snip = [NSString pathWithComponents:pathComponents];
    NSString *path = appPath_;
    NSURL *file = [script scriptFile];
    if (file) {
      path = [file path];
    }
    NSString *uri = _FSItemURI(name, snip);
    NSString *app = _FSItemApp(pathComponents);
    HGSAction *action = _FSItemAction();
    NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                           script, kFSScriptItemKey,
                           action, kHGSObjectAttributeDefaultActionKey,
                           snip, kHGSObjectAttributeSnippetKey,
                           path, kHGSObjectAttributeIconPreviewFileKey,
                           app, kFSAppNameKey,
                           nil];
    HGSResult *result = [HGSUnscoredResult resultWithURI:uri
                                                    name:name
                                                    type:kFSResultType
                                                  source:self
                                              attributes:attrs];
    [self indexResult:result];
  }
}

- (void)indexScriptLibrary:(FastScriptsScriptLibrary *)library
      atPathWithComponents:(NSArray *)pathComponents
                 operation:(NSOperation *)operation {
  if (![operation isCancelled]) {
    for (FastScriptsScriptItem *script in [library scriptItems]) {
      [self indexScriptItem:script
       atPathWithComponents:pathComponents
                  operation:operation];
    }
    for (FastScriptsScriptLibrary *sublibrary in [library scriptLibraries]) {
      NSString *name = [sublibrary name];
      NSArray *subpathComponents = [pathComponents arrayByAddingObject:name];
      [self indexScriptLibrary:sublibrary
          atPathWithComponents:subpathComponents
                     operation:operation];
    }
  }
}

- (void)indexScriptsForApp:(FastScriptsApplication *)application
                         operation:(NSOperation *)operation {
  if (![operation isCancelled]) {
    NSArray *topLevelScriptLibraries = [application topLevelScriptLibraries];
    for (FastScriptsScriptLibrary *library in topLevelScriptLibraries) {
      [self indexScriptLibrary:library
          atPathWithComponents:[NSArray array]
                     operation:operation];
    }
  }
}

#pragma mark Result Filtering
- (BOOL)isResult:(HGSResult *)result
     validForApp:(NSString *)otherApp
           orNil:(BOOL)nilOK {
  BOOL valid = nilOK;
  NSString *scriptApp = [result valueForKey:kFSAppNameKey];
  if (scriptApp) {
    valid = [scriptApp caseInsensitiveCompare:otherApp] == NSOrderedSame;
  }
  return valid;
}

- (HGSResult *)preFilterResult:(HGSResult *)result
               matchesForQuery:(HGSQuery *)query
                  pivotObjects:(HGSResultArray *)pivotObjects {
  BOOL valid = NO;
  if ([pivotObjects count]) {
    for (HGSResult *pivot in pivotObjects) {
      if (!valid) {
        valid = [self isResult:result validForApp:[pivot displayName] orNil:NO];
      }
    }
  } else {
    NSDictionary *appInfo = [[NSWorkspace sharedWorkspace] activeApplication];
    NSString *appName = [appInfo objectForKey:@"NSApplicationName"];
    valid = [self isResult:result validForApp:appName orNil:YES];
  }
  return valid ? result : nil;
}

@end
