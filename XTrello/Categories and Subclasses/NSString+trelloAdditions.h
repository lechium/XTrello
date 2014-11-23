//
//  NSString+trelloAdditions.h
//  XTrello
//
//  Created by Kevin Bradley on 7/10/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
@interface NSString (trelloAdditions)

- (CGFloat)heightForStringWithFont:(NSFont *)myFont withWidth:(CGFloat)myWidth;
- (NSDictionary *)dictionaryRepresentation;
- (NSColor *)colorFromName;
- (NSString *)tildePath;
@end
