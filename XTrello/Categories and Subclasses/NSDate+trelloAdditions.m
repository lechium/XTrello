//
//  NSDate+trelloAdditions.m
//  XTrello
//
//  Created by Kevin Bradley on 7/17/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import "NSDate+trelloAdditions.h"

@implementation NSDate (trelloAdditions)

- (NSString *)timeStringFromCurrentDate
{
    NSDate *currentDate = [NSDate date];
    NSTimeInterval timeInt = [currentDate timeIntervalSinceDate:self];
    // NSLog(@"timeInt: %f", timeInt);
    NSInteger minutes = floor(timeInt/60);
    NSInteger seconds = round(timeInt - minutes * 60);
    return [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)seconds];
    
}


@end
