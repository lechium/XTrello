//
//  NSArray+trelloAdditions.h
//  XTrello
//
//  Created by Kevin Bradley on 7/12/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (trelloAdditions)
- (NSString *)labelString;
- (BOOL)containsString:(NSString *)theString; //will check to see if any object in the array contains
//even part of a string;
@end
