//
//  NSView+trelloAdditions.m
//  XTrello
//
//  Created by Kevin Bradley on 7/11/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import "NSView+trelloAdditions.h"

@implementation NSView (trelloAdditions)

- (void)insertSubview:(NSView *)theView atIndex:(NSInteger)index
{
    NSMutableArray *mutableSubviews = [[self subviews] mutableCopy];
    [mutableSubviews insertObject:theView atIndex:index];
    [self setSubviews:mutableSubviews];
}

@end
