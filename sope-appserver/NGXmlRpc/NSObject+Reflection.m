/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include "common.h"
#import <objc/objc.h>
#import <objc/Protocol.h>

#if NeXT_RUNTIME || APPLE_RUNTIME
#  import <objc/objc.h>
#  import <objc/objc-class.h>
#elif OLD_GCC // hh: 2024-09-02: doesn't exist anymore
#  import <objc/encoding.h>
#else // does not provide the old API
#  import <objc/objc.h>
#  import <objc/runtime.h>
#  include <assert.h>
#endif

@implementation NSObject(Reflection)

+ (void)_addSelectorsOfClassToArray:(NSMutableSet *)_sels {
#if TODO_PORT_XML_RPC_REFLECTION
#if GNU_RUNTIME
  MethodList_t methods;
  
  for (methods = ((Class)self)->methods; methods;
       methods = methods->method_next) {
    int i;
    
    for (i = 0; i < methods->method_count; i++) {
      Method_t internalMethod;
      SEL      sel;
      NSString *selName;
      
      internalMethod = &(methods->method_list[i]);
      sel     = internalMethod->method_name;
      selName = NSStringFromSelector(sel);
      
      if (![selName isNotEmpty]) {
        NSLog(@"WARNING(%s): did not get selector for method 0x%p",
              __PRETTY_FUNCTION__, internalMethod);
        continue;
      }
      
      [_sels addObject:selName];
    }
  }
#else
  struct objc_method_list *mlist;
  void *iterator = NULL;
  
  //NSLog(@"adding selectors of class: %@", NSStringFromClass(self));
  
  while ((mlist = class_nextMethodList(self, &iterator)) != NULL) {
    int mcount;
    
    //NSLog(@"  processing %i selectors ...", mlist->method_count);
    
    for (mcount = mlist->method_count; mcount > 0; mcount--) {
      NSString *selName;
      SEL sel;
      
      if ((sel = mlist->method_list[mcount - 1].method_name) == NULL)
        continue;
      
      selName = NSStringFromSelector(sel);
      if (![selName isNotEmpty]) {
        NSLog(@"WARNING(%s): did not get selector for method 0x%p",
              __PRETTY_FUNCTION__, mlist->method_list[mcount - 1]);
        continue;
      }
      [_sels addObject:selName];
    }
  }
#endif
#else
  assert(0); // NOT IMPLEMENTED
#endif // TODO_PORT_XML_RPC_REFLECTION
}

+ (NSArray *)classImplementsSelectors {
  NSMutableSet *a;
  
  a = [[[NSMutableSet alloc] initWithCapacity:32] autorelease];
  [self _addSelectorsOfClassToArray:a];
  return [a allObjects];
}

+ (NSArray *)instancesRespondToSelectors {
  NSMutableSet *a;
  Class clazz;
  
  a = [NSMutableSet setWithCapacity:128];
  for (clazz = self; clazz; clazz = [clazz superclass])
    [clazz _addSelectorsOfClassToArray:a];
  return [a allObjects];
}

- (NSArray *)respondsToSelectors {
  return [[self class] instancesRespondToSelectors];
}

@end /* NSObject(Reflection) */
