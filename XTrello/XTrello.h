//
//  XTrello.h
//  XTrello
//
//  Created by Kevin Bradley on 7/14/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "XTTableView.h"
#import "XTModel.h"
#import "XTWindowController.h"



@interface XTrello : NSObject <XTWindowControllerDelegate>
{
    NSString *theToken;
    NSString *baseURL;
    NSString *apiKey;
    BOOL trelloReady;
    NSDictionary *trelloData;
    NSMenuItem *xtrelloWindowMenuItem;
    NSMenuItem *xtrelloBrowserWindowMenuItem;
    NSTimer *refreshTimer;
}


@end