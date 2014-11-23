//
//  XTrelloItem.h
//  XTrello
//
//  Created by Kevin Bradley on 7/15/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XTrelloItem : NSObject

@property (nonatomic, copy) NSString* filePath;
@property (nonatomic, assign) NSUInteger lineNumber;
@property (nonatomic, copy) NSString* content;
@property (nonatomic, copy) NSString* branch;

- (id)initWithString:(NSString *)theString;

@end
