//
//  FastScriptsAction.m
//
//  Copyright (c) 2009  Martin Kuehl <purl.org/net/mkhl>
//  Licensed under the MIT License.
//

#import <Vermilion/Vermilion.h>
#import "FastScriptsBridge.h"
#import "Macros.h"

#pragma mark HGSResult Keys
extern NSString *kFSScriptItemKey;
extern NSString *kFSAppNameKey;

#pragma mark HGSResult Type
extern NSString *kFSResultType;

@interface FastScriptsAction : HGSAction
@end

@implementation FastScriptsAction

- (BOOL)performWithInfo:(NSDictionary*)info {
  BOOL success = NO;
  HGSResultArray *objects = [info objectForKey:kHGSActionDirectObjectsKey];
  for (HGSResult *result in objects) {
    FastScriptsScriptItem *script = [result valueForKey:kFSScriptItemKey];
    if (script == nil) {
      HGSLogDebug(@"%@: Missing ScriptItem for Result: %@", self, result);
      continue;
    }
    [script invoke];
    success = YES;
  }
  return success;
}

@end
