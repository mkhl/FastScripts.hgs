//
//  FastScriptsAction.m
//
//  Copyright (c) 2009-2010  Martin Kuehl <purl.org/net/mkhl>
//  Licensed under the MIT License.
//

#import "FastScriptsSource.h"

@interface FastScriptsAction : HGSAction
@end

@implementation FastScriptsAction

- (BOOL)performWithInfo:(NSDictionary *)info {
  BOOL success = NO;
  HGSResultArray *objects = [info objectForKey:kHGSActionDirectObjectsKey];
  for (HGSResult *result in objects) {
    FastScriptsScriptItem *script = [result valueForKey:kFSScriptItemKey];
    if (script) {
      [script invoke];
      success = YES;
    }
  }
  return success;
}

@end
