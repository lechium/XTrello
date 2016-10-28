//
//  NSMenuItem+boardDict.m
//  XTrello
//
//  Created by Kevin Bradley on 10/28/16.
//  Copyright © 2016 GlobalMed LLC. All rights reserved.
//

#import "NSMenuItem+boardDict.h"

@implementation NSObject (AMAssociatedObjects)


- (void)associateValue:(id)value withKey:(void *)key
{
    objc_setAssociatedObject(self, key, value, OBJC_ASSOCIATION_RETAIN);
}

- (void)weaklyAssociateValue:(id)value withKey:(void *)key
{
    objc_setAssociatedObject(self, key, value, OBJC_ASSOCIATION_ASSIGN);
}

- (id)associatedValueForKey:(void *)key
{
    return objc_getAssociatedObject(self, key);
}

@end


@implementation NSMenuItem (boardDict)

- (NSDictionary *)boardDictionary
{
    return [self associatedValueForKey:@selector(boardDictionary)];
}

- (void)setBoardDictionary:(NSDictionary *)boardDictionary
{
    [self associateValue:boardDictionary withKey:@selector(boardDictionary)];
}

@end
