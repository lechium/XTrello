//
//  NSDictionary+trelloAdditions.m
//  XTrello
//
//  Created by Kevin Bradley on 7/10/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import "NSDictionary+trelloAdditions.h"

@implementation NSDictionary (trelloAdditions)


- (NSString *)stringRepresentation
{
	NSString *error = nil;
	NSData *xmlData = [NSPropertyListSerialization dataFromPropertyList:self format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];
	NSString *s=[[NSString alloc] initWithData:xmlData encoding: NSUTF8StringEncoding];
	return s;
}


- (NSDictionary *)dictionaryByReplacingNullsWithStrings {
    const NSMutableDictionary *replaced = [self mutableCopy];
    const id nul = [NSNull null];
    const NSString *blank = @"";
    
    for(NSString *key in self) {
        const id object = [self objectForKey:key];
        if(object == nul) {
            //pointer comparison is way faster than -isKindOfClass:
            //since [NSNull null] is a singleton, they'll all point to the same
            //location in memory.
            [replaced setObject:blank
                         forKey:key];
        }
        if ([object respondsToSelector:@selector(allKeys)])
        {
            id newObject = [object dictionaryByReplacingNullsWithStrings];
            [replaced setObject:newObject forKey:key];
        }
    }
    
    return [replaced copy];
}

@end