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

#pragma mark HGSResult Type
extern NSString *kFSResultType;

@interface FastScriptsAction : HGSAction
@end

@implementation FastScriptsAction

- (BOOL)performWithInfo:(NSDictionary*)info {
  HGSResultArray *objects = [info objectForKey:kHGSActionDirectObjectsKey];
  if (isEmpty(objects))
    return NO;
  for (HGSResult *result in objects) {
    FastScriptsScriptItem *script = [result valueForKey:kFSScriptItemKey];
    if (script == nil)
      HGSLogDebug(@"%@: Missing ScriptItem for Result: %@", self, result);
    [script invoke];
  }
  return YES;
}

@end
