//
//  NSDictionary+trelloAdditions.h
//  XTrello
//
//  Created by Kevin Bradley on 7/10/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (trelloAdditions)
- (NSDictionary *)dictionaryByReplacingNullsWithStrings;
- (NSString *)stringRepresentation;
@end
