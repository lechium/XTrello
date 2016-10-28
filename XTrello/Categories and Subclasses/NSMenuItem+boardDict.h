//
//  NSMenuItem+boardDict.h
//  XTrello
//
//  Created by Kevin Bradley on 10/28/16.
//  Copyright © 2016 GlobalMed LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

@interface NSObject (AMAssociatedObjects)
- (void)associateValue:(id)value withKey:(void *)key; // Strong reference
- (void)weaklyAssociateValue:(id)value withKey:(void *)key;
- (id)associatedValueForKey:(void *)key;

@end


@interface NSMenuItem (boardDict)

@property (nonatomic) NSDictionary *boardDictionary;

@end
