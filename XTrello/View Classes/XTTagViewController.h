//
//  XTTagViewController.h
//  XTrello
//
//  Created by Kevin Bradley on 7/11/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "XTTagView.h"

@interface XTTagViewController : NSView

@property (nonatomic, strong) NSArray *labels;

- (id)initWithFrame:(NSRect)frame andLabels:(NSArray *)labelArray;

- (void)updateLabels:(NSArray *)theLabels;

@end
