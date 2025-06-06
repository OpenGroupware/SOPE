/* 
   NSCalendarDate+PGVal.m

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess
   Copyright (C) 2000-2008 SKYRIX Software AG and Helge Hess

   Author: Helge Hess (helge@opengroupware.org)

   This file is part of the PostgreSQL72 Adaptor Library

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#import <Foundation/NSString.h>
#include "PostgreSQL72Channel.h"
#include "common.h"

// Date: Oct 21 1997  9:52:26:000PM 
static NSString *PGSQL_DATETIME_FORMAT = @"%b %d %Y %I:%M:%S:000%p";

@implementation NSCalendarDate(PostgreSQL72Values)

/*
  Format: '2001-07-26 14:00:00+02'        (len 22)
          '2001-07-26 14:00:00+09:30'     (len 25)
  those can have .1 to .999999 (microseconds)
          '2008-01-31 14:00:57.2+01'      (len 24)
	        '2008-01-31 14:00:57.249+01'    (len 26)
          '2024-11-25 16:01:36.549802+00' (len 29) hh(2024-11-26)
           0123456789012345678901234
  
  Matthew: "07/25/2003 06:00:00 CDT".
*/

static Class      NSCalDateClass     = Nil;
static NSTimeZone *DefServerTimezone = nil;
static NSTimeZone *gmt   = nil;
static NSTimeZone *gmt01 = nil;
static NSTimeZone *gmt02 = nil;

+ (id)valueFromCString:(const char *)_cstr length:(int)_length
  postgreSQLType:(NSString *)_type
  attribute:(EOAttribute *)_attribute
  adaptorChannel:(PostgreSQL72Channel *)_channel
{
  char           buf[32];
  char           *p;
  NSTimeZone     *attrTZ;
  NSCalendarDate *date;
  int            year, month, day, hour, min, sec, tzOffset = 0;
  char *tok;
  
  if (_length == 0)
    return nil;
  
  if (_length != 22 && _length != 25 && !(_length >= 24 && _length <= 29)) {
    // TODO: add support for "2001-07-26 14:00:00" (len=19)
    // TBD: add support for "2008-01-31 14:00:57.249+01" (len=26)
    NSLog(@"ERROR(%s): unexpected string '%s' for date type '%@' "
	        @"(expected format: '2001-07-26 14:00:00+02')", 
	        __PRETTY_FUNCTION__, _cstr, _type);
    [NSException raise:@"PGAdaptorException"
                 format:@"Unexpected date string '%s' type %@", _cstr, _type];
    return nil;
  }
  strncpy(buf, _cstr, 29);
  buf[29] = '\0';
  
  /*
    Format: '2001-07-26 14:00:00+02'        (len 22)
            '2001-07-26 14:00:00+09:30'     (len 25)
            '2008-01-31 14:00:57.249+01'    (len 26)
            '2024-11-25 16:01:36.549802+00' (len 29) hh(2024-11-26)
             0123456789012345678901234
    
    Matthew: "07/25/2003 06:00:00 CDT".
  */
  // strsep() - locate delimiter, replace it w/ `\0`, update reference after
  //            the delim, return the original input.
  tok = buf;
  year  = atoi(strsep(&tok, "-")); // 2001-07-26 14:00:00+02
  month = atoi(strsep(&tok, "-")); // 07-26 14:00:00+02
  day   = atoi(strsep(&tok, " ")); // 26 14:00:00+02
  hour  = atoi(strsep(&tok, ":")); // 14:00:00+02
  min   = atoi(strsep(&tok, ":")); // 00:00+02
  
  // parse timezone, this DOES modify `tok`/`buf` during time parsing
  tzOffset = 0; // ptr to timezone part
  if (tok != NULL && (p = strchr(tok, '+')) != NULL)
    tzOffset = +1; // positive tz
  else if (tok != NULL && (p = strchr(tok, '-')) != NULL)
    tzOffset = -1; // negative tz
  else
    tzOffset = 0; // TBD: warn?
  if (tzOffset != 0) { // has timezone, parse it. `p` is set
    int tzHours, tzMins = 0;
    
    p++; // skip +/-   in: `+02` or `-02`
    tzHours = atoi(strsep(&p, ":")); // in: 02:30
    if (p != NULL) tzMins = atoi(p); // if the offset is `+02:30`
    
    tzMins   = tzHours * 60 + tzMins; // calculate minutes
    tzOffset = tzOffset < 0 ? -tzMins : tzMins; // apply positive/negative
  }

  /* extract seconds */
  // this does NOT preserve the milliseconds part (.249 or .549802)
  sec = atoi(strsep(&tok, ":+.")); // in: 00+02 or 36.549802+00
  
#if HEAVY_DEBUG    
  NSLog(@"DATE: %s => %04i-%02i-%02i %02i:%02i:%02i",
      	buf, year, month, day, hour, min, sec);
#endif
#if HEAVY_DEBUG
  NSLog(@"DATE: %s => OFFSET %i", _cstr, tzOffset);
#endif
  
  /* TODO: cache all timezones (just 26 ;-) */
  switch (tzOffset) {
  case 0:
    if (gmt == nil) {
      gmt = [[NSTimeZone timeZoneForSecondsFromGMT:0] retain];
      NSAssert(gmt, @"could not create GMT timezone?!");
    }
    attrTZ = gmt;
    break;
  case 60:
    if (gmt01 == nil) {
      gmt01 = [[NSTimeZone timeZoneForSecondsFromGMT:3600] retain];
      NSAssert(gmt01, @"could not create GMT+01 timezone?!");
    }
    attrTZ = gmt01;
    break;
  case 120:
    if (gmt02 == nil) {
      gmt02 = [[NSTimeZone timeZoneForSecondsFromGMT:7200] retain];
      NSAssert(gmt02, @"could not create GMT+02 timezone?!");
    }
    attrTZ = gmt02;
    break;
    
  default: {
    /* cache the first, "alternative" timezone */
    static int firstTZOffset = 0; // can use 0 since GMT is a separate case
    static NSTimeZone *firstTZ = nil;
    if (firstTZOffset == 0) {
      firstTZOffset = tzOffset;
      firstTZ = [[NSTimeZone timeZoneForSecondsFromGMT:(tzOffset*60)] retain];
    }
    
    attrTZ = (firstTZOffset == tzOffset)
      ? firstTZ
      : [NSTimeZone timeZoneForSecondsFromGMT:(tzOffset * 60)];
    break;
  }
  }
  
  if (NSCalDateClass == Nil) NSCalDateClass = [NSCalendarDate class];
  date = [NSCalDateClass dateWithYear:year month:month day:day
			 hour:hour minute:min second:sec
			 timeZone:attrTZ];
  if (date == nil) {
    NSLog(@"ERROR(%s): could not construct date from string '%s': "
          @"year=%i,month=%i,day=%i,hour=%i,minute=%i,second=%i, tz=%@",
          __PRETTY_FUNCTION__, _cstr,
          year, month, day, hour, min, sec, attrTZ);
    [NSException raise:@"PGAdaptorException"
                 format:
                   @"Could not construct date from string '%s': "
                   @"year=%i,month=%i,day=%i,hour=%i,minute=%i,second=%i, tz=%@",
                   _cstr, year, month, day, hour, min, sec, attrTZ];
  }
  return date;
}

+ (id)valueFromBytes:(const void *)_bytes length:(int)_length
  postgreSQLType:(NSString *)_type
  attribute:(EOAttribute *)_attribute
  adaptorChannel:(PostgreSQL72Channel *)_channel
{
#if COCOA_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
  NSLog(@"%s: not implemented!", __PRETTY_FUNCTION__);
  return nil;
#else
  return [self notImplemented:_cmd];
#endif
}

- (NSString *)stringValueForPostgreSQLType:(NSString *)_type
  attribute:(EOAttribute *)_attribute
{
#if 0
  NSString   *format;
#endif
  EOQuotedExpression *expr;
  NSTimeZone *serverTimeZone;
  NSString   *format;
  NSString   *val;
  
  if ((serverTimeZone = [_attribute serverTimeZone]) == nil ) {
    if (DefServerTimezone == nil) {
      DefServerTimezone = [[NSTimeZone localTimeZone] retain];
      NSLog(@"Note: PostgreSQL72 adaptor using timezone '%@' as default",
	    DefServerTimezone);
    }
    serverTimeZone = DefServerTimezone;
  }
  
#if 0
  format = [_attribute calendarFormat];
#else /* hm, why is that? */
  format = @"%Y-%m-%d %H:%M:%S%z";
#endif
  if (format == nil)
    format = PGSQL_DATETIME_FORMAT;
  
  [self setTimeZone:serverTimeZone];
  
  val = [self descriptionWithCalendarFormat:format];
  expr = [[EOQuotedExpression alloc] initWithExpression:val
				     quote:@"\'" escape:@"\\'"];
  val = [[expr expressionValueForContext:nil] retain];
  [expr release];
  
  return [val autorelease];
}

@end /* NSCalendarDate(PostgreSQL72Values) */
