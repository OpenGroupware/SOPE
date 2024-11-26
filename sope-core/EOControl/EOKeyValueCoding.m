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

#include "EOKeyValueCoding.h"
#include "EONull.h"
#include "common.h"

#if !LIB_FOUNDATION_LIBRARY
#if GNU_RUNTIME

#if __GNU_LIBOBJC__ >= 20100911
#  include <objc/runtime.h>
#else
#  include <objc/encoding.h>
#  include <objc/objc-api.h>
#endif

#endif

static EONull *null = nil;


@implementation NSArray(EOKeyValueCoding)

- (id)computeSumForKey:(NSString *)_key {
  static Class    NSDecimalNumberClass;
  id              (*objAtIdx)(id, SEL, unsigned int);
  unsigned        i, cc = [self count];
  NSDecimalNumber *sum;

  if (NSDecimalNumberClass == Nil)
    NSDecimalNumberClass = [NSDecimalNumber class];

  sum = [NSDecimalNumber zero];
  if (cc == 0) return sum;

  objAtIdx = (void*)[self methodForSelector:@selector(objectAtIndex:)];

  for (i = 0; i < cc; i++) {
    register id o;
    
    o = objAtIdx(self, @selector(objectAtIndex:), i);
    o = [o valueForKey:_key];

    if (![o isKindOfClass:NSDecimalNumberClass])
      o = (NSDecimalNumber *)[NSDecimalNumber numberWithDouble:[o doubleValue]];
    sum = [sum decimalNumberByAdding:o];
  }
  return sum;
}

- (id)computeAvgForKey:(NSString *)_key {
  unsigned        cc = [self count];
  NSDecimalNumber *sum, *div;
    
  if (cc == 0) return nil;
  
  sum = [self computeSumForKey:_key];
  div = (NSDecimalNumber *)[NSDecimalNumber numberWithUnsignedInt:cc];
  return [sum decimalNumberByDividingBy:div];
}

- (id)computeCountForKey:(NSString *)_key {
  return [NSNumber numberWithUnsignedInt:[self count]];
}

- (id)computeMaxForKey:(NSString *)_key {
  id              (*objAtIdx)(id, SEL, unsigned int);
  unsigned        i, cc = [self count];
  NSDecimalNumber *max;
  
  if (cc == 0) return nil;

  objAtIdx = (void*)[self methodForSelector:@selector(objectAtIndex:)];
  max      = [objAtIdx(self, @selector(objectAtIndex:), 0) valueForKey:_key];

  for (i = 1; i < cc; i++) {
    register id o;
      
    o = [objAtIdx(self, @selector(objectAtIndex:), i) valueForKey:_key];
    if ([max compare:o] == NSOrderedAscending)
      max = o;
  }
  return max;
}

- (id)computeMinForKey:(NSString *)_key {
  id              (*objAtIdx)(id, SEL, unsigned int);
  unsigned        i, cc = [self count];
  NSDecimalNumber *min;
  
  if (cc == 0) return nil;
  
  objAtIdx = (void*)[self methodForSelector:@selector(objectAtIndex:)];
  min      = [objAtIdx(self, @selector(objectAtIndex:), 0) valueForKey:_key];

  for (i = 1; i < cc; i++) {
    register id o;
    
    o = [objAtIdx(self, @selector(objectAtIndex:), i) valueForKey:_key];
    if ([min compare:o] == NSOrderedDescending)
      min = o;
  }
  return min;
}

- (id)valueForKey:(NSString *)_key {
  if (null == nil) null = [[EONull null] retain];
  
  if ([_key hasPrefix:@"@"]) {
    /* process a computed function */
    const char *keyStr;
    char       *bufPtr;
    unsigned   keyLen = [_key cStringLength];
    char       *kbuf, *buf;
    SEL        sel;

    kbuf = malloc(keyLen + 1);
    buf  = malloc(keyLen + 16);
    [_key getCString:kbuf];
    keyStr = kbuf;
    bufPtr = buf;
    strcpy(buf, "compute");       bufPtr += 7;
    *bufPtr = toupper(keyStr[1]); bufPtr++;
    strncpy(&(buf[8]), &(keyStr[2]), keyLen - 2); bufPtr += (keyLen - 2);
    strcpy(bufPtr, "ForKey:");
    if (kbuf) free(kbuf);

    sel = sel_registerName(buf);
    if (buf) free(buf);
    
    return sel != NULL ? [self performSelector:sel withObject:_key] : nil;
  }
  else {
    /* process the _key in a map function */
    unsigned i, cc = [self count];
    NSArray  *result;
    id *objects;
    id (*objAtIdx)(id, SEL, unsigned int);

#if DEBUG
    if ([_key isEqualToString:@"count"]) {
      NSLog(@"WARNING(%s): USED -valueForKey(@\"count\") ON NSArray, YOU"
            @"PROBABLY WANT TO USE @count INSTEAD !",
            __PRETTY_FUNCTION__);
      return [self valueForKey:@"@count"];
    }
#endif
    
    if (cc == 0) return [NSArray array];
    
    objects = calloc(cc + 2, sizeof(id));
    objAtIdx = (void *)[self methodForSelector:@selector(objectAtIndex:)];
    
    for (i = 0; i < cc; i++) {
      register id o;
      
      o = [objAtIdx(self, @selector(objectAtIndex:), i) valueForKey:_key];
      objects[i] = o ? o : (id)null;
    }
    
    result = [NSArray arrayWithObjects:objects count:cc];
    if (objects) free(objects);
    return result;
  }
}

@end /* NSArray(EOKeyValueCoding) */

#endif /* !LIB_FOUNDATION */
