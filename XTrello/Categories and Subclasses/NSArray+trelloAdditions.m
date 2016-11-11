//
//  NSArray+trelloAdditions.m
//  XTrello
//
//  Created by Kevin Bradley on 7/12/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import "NSArray+trelloAdditions.h"

@implementation NSArray (trelloAdditions)

- (NSString *)labelString;
{
    NSMutableArray *newArray = [NSMutableArray new];
    NSString *returnString = nil;
    for (NSDictionary *currentColor in self)
    {
        if (![currentColor respondsToSelector:@selector(allKeys)])return nil;
        
        //[newArray addObject:[currentColor key]];
        
    }
    
    if ([newArray count] > 0)
    {
        returnString = [newArray componentsJoinedByString:@","];
    }
    
    return returnString;
}

- (BOOL)containsString:(NSString *)theString
{
    NSInteger idx = [self indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
       
        if ([obj rangeOfString:theString].location != NSNotFound)
        {
            return YES;
        } else {
            return NO;
        }
        
    }];
    
    if (idx == NSNotFound) return NO;
    
    return YES;
    
}

@end
