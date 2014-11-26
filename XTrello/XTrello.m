//
//  XTrello.m
//  XTrello
//
//  Created by Kevin Bradley on 7/14/14.
//    Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import "XTrello.h"
#import <objc/runtime.h>

@interface DVTCompletingTextView : NSTextView
@end
@interface DVTSourceTextView : DVTCompletingTextView
- (long long)_currentLineNumber;
@end

@interface DVTSourceLandmarkItem : NSObject
@property long long indentLevel; // @synthesize indentLevel=_indentLevel;
@property long long nestingLevel; // @synthesize nestingLevel=_nestingLevel;
@property(readonly) double timestamp; // @synthesize timestamp=_timestamp;
@property(nonatomic) struct _NSRange nameRange; // @synthesize nameRange=_nameRange;
@property(nonatomic) struct _NSRange range; // @synthesize range=_range;
@property(readonly) int type; // @synthesize type=_type;
@property(copy, nonatomic) NSString *name; // @synthesize name=_name;
@property DVTSourceLandmarkItem *parent; // @synthesize parent=_parent;
@property(readonly) BOOL needsUpdate;
@property(readonly) long long numberOfChildren;
@property(readonly) NSMutableArray *_children;
@property(readonly) NSArray *children;
@end

@class DVTSourceLandmarkItem;

@interface XTrello ()
@property (nonatomic, strong) XTWindowController* windowController;
- (id)originalTextView:(id)arg1 menu:(id)arg2 forEvent:(id)arg3 atIndex:(unsigned long long)arg4;
- (void)originalSetupTextViewContextMenuWithMenu:(id)arg1;
- (void)setupTextViewContextMenuWithMenu:(id)arg1;
@end

static XTrello *XTrelloSharedPlugin;

@interface XTrello()

@property (nonatomic, strong) NSBundle *bundle;
@end

@implementation XTrello


+ (void)initialize
{
    NSDictionary *appDefaults = @{kXTrelloRefreshRate: [NSNumber numberWithInt:5], kXTrelloFloatingWindow: [NSNumber numberWithBool:TRUE] };
    [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
}




- (void)setupTextViewContextMenuWithMenu:(id)arg1 {}

- (id)originalTextView:(id)arg1 menu:(id)arg2 forEvent:(id)arg3 atIndex:(unsigned long long)arg4 { return nil; } //these dont matter, just here to keep us from complaini
- (void)originalSetupTextViewContextMenuWithMenu:(id)arg1 { }

- (void)removeItemForWindowTag:(NSInteger)windowTag
{
    //1 = main, 2 = browser, 3 = prefs
 
    NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Window"];
    switch (windowTag) {
        
        case 1:
            
            xtrelloWindowMenuItem = [[menuItem submenu] itemWithTitle:@"Xtrello Cards"];
            if (xtrelloWindowMenuItem != nil)
                [[menuItem submenu] removeItem:xtrelloWindowMenuItem];
            
            break;
            
        case 2:
            
            xtrelloBrowserWindowMenuItem = [[menuItem submenu] itemWithTitle:@"Xtrello Browser"];
            if (xtrelloBrowserWindowMenuItem != nil)
                [[menuItem submenu] removeItem:xtrelloBrowserWindowMenuItem];
            
            break;
    }
}

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            XTrelloSharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

- (id)initWithBundle:(NSBundle *)plugin
{
    if (self = [super init]) {
        // reference to plugin's bundle, for resource acccess
        self.bundle = plugin;
        
        // Create menu items, initialize UI, etc.

       // NSLog(@"dataStoreFile: %@", [XTModel boardsDataStoreFile]);
          [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectionDidChange:) name:NSTextViewDidChangeSelectionNotification object:nil];
    
        if (self.windowController == nil) {
            XTWindowController* wc = [[XTWindowController alloc] initWithWindowNibName:@"XTWindowController"];
            self.windowController = wc;
            wc.delegate = self;
            
        }
        
        NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"View"];
        if (menuItem) {
            [[menuItem submenu] addItem:[NSMenuItem separatorItem]];
            
            NSMenuItem *trelloMenuItem = [[NSMenuItem alloc] init];
            [trelloMenuItem setTitle:@"Trello"];
            
            NSMenu *trelloMenu = [[NSMenu alloc] initWithTitle:@""];
            
            
            NSMenuItem *actionMenuItem = [[NSMenuItem alloc] initWithTitle:@"Show Trello boards" action:@selector(showTrelloWindow) keyEquivalent:@"t"];
            [actionMenuItem setKeyEquivalentModifierMask:NSControlKeyMask];
            [actionMenuItem setTarget:self];
            //[[menuItem submenu] addItem:actionMenuItem];
            [trelloMenu addItem:actionMenuItem];
            NSMenuItem *trelloItem = [[NSMenuItem alloc] initWithTitle:@"Add Card to Trello..." action:@selector(newCardFromMenu:) keyEquivalent:@"c"];
            [trelloItem setKeyEquivalentModifierMask:NSControlKeyMask];
            [trelloItem setTarget:self.windowController];
            [trelloMenu addItem:trelloItem];
            NSMenuItem *prefItem = [[NSMenuItem alloc] initWithTitle:@"Create Board for Current Project..." action:@selector(createBoardForCurrentProject) keyEquivalent:@""];
            [prefItem setTarget:self];
            [trelloMenu addItem:prefItem];
            [trelloMenuItem setSubmenu:trelloMenu];
            [[menuItem submenu] addItem:trelloMenuItem];
        }
        XTTrelloWrapper *trelloInst = [XTTrelloWrapper sharedInstance];
        
        [trelloInst setApiKey:[[NSUserDefaults standardUserDefaults]objectForKey:kXTrelloAPIKey]];
        [trelloInst setSessionToken:[[NSUserDefaults standardUserDefaults]objectForKey:kXTrelloAuthToken]];
        [trelloInst setBaseURL:@"https://trello.com/1"];
        [trelloInst setDelegate:self];
        [trelloInst loadPreviousData];
        
        [trelloInst fetchTrelloData];
    
        static dispatch_once_t onceToken2;
        dispatch_once(&onceToken2, ^{
            
            
            // get the class definition responsible for populating the context menu
            
            Class sourceTextClass = NSClassFromString(@"IDESourceCodeEditor");
            
            /* 
             
             sample update science.
             
             first attempt to shoehorn in was unsuccessful, originalTextView:menu:forEvent:atIndex:) appears to be called before setupTextViewContextMenuWithMenu
             where the real magic happens,
             
             add the newTextView:menu:forEvent:atIndex: method on self as a method on the IDESourceCodeEditor class, but name it newTextView:menu:forEvent:atIndex:
             
             */
            /*
            Method ourMenuForEvent = class_getInstanceMethod([self class], @selector(newTextView:menu:forEvent:atIndex:));
            class_addMethod(sourceTextClass, @selector(originalTextView:menu:forEvent:atIndex:), method_getImplementation(ourMenuForEvent), method_getTypeEncoding(ourMenuForEvent));
            
            // swap the textView:menu:forEvent:atIndex: and newTextView:menu:forEvent:atIndex: methods on IDESourceCodeEditor
            Method themeFrameDrawRect = class_getInstanceMethod(sourceTextClass, @selector(textView:menu:forEvent:atIndex:));
            Method themeFrameDrawRectOriginal = class_getInstanceMethod(sourceTextClass, @selector(originalTextView:menu:forEvent:atIndex:));
            method_exchangeImplementations(themeFrameDrawRect, themeFrameDrawRectOriginal);
            
             swizzling is dangerous and should only be used as a last resort!!!
             
             https://mikeash.com/pyblog/friday-qa-2010-01-29-method-replacement-for-fun-and-profit.html
             
             
             
            */
            
            Method ourContextReplacement = class_getInstanceMethod([self class], @selector(XTSetupTextViewContextMenuWithMenu:));
            class_addMethod(sourceTextClass, @selector(originalSetupTextViewContextMenuWithMenu:), method_getImplementation(ourContextReplacement), method_getTypeEncoding(ourContextReplacement));
            
            Method sourceSetupContextMenu = class_getInstanceMethod(sourceTextClass, @selector(setupTextViewContextMenuWithMenu:));
            Method sourceSetupContextOriginal = class_getInstanceMethod(sourceTextClass, @selector(originalSetupTextViewContextMenuWithMenu:));
            method_exchangeImplementations(sourceSetupContextMenu, sourceSetupContextOriginal);
            
            
            //if we dont add our methods to IDESourceCodeEditor our menu items are disabled and useless.
            
        //    Method itsScience = class_getInstanceMethod([self class], @selector(itsScience:));
            
          //  class_addMethod(sourceTextClass, @selector(itsScience:), method_getImplementation(itsScience), method_getTypeEncoding(itsScience));
        });
        
        NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
        
        [prefs addObserver:self
                forKeyPath:kXTrelloRefreshRate
                   options:NSKeyValueObservingOptionNew
                   context:NULL];
        
        [prefs addObserver:self
                forKeyPath:kXTrelloAuthToken
                   options:NSKeyValueObservingOptionNew
                   context:NULL];
        
    }
    return self;
}

- (void)createBoardForCurrentProject
{
    NSString *projectName = [XTModel currentProjectName];
    NSLog(@"projectname: %@", projectName);
    if (projectName != nil)
    {
        NSString *orgName = [[XTTrelloWrapper sharedInstance] firstOrganizationName];
        if (orgName == nil)
        {
            NSLog(@"no org!!");
            return;
        }
        //TODO: check to see if we are in an organization
        [[XTTrelloWrapper sharedInstance] createNewTemplateBoardWithName:projectName inOrganization:orgName];
        self.windowController.boardsLoaded = false;
        [[XTTrelloWrapper sharedInstance] reloadTrelloData];
    }
}

- (void)setInitialData:(NSDictionary *)theData
{
    trelloData = theData;
    NSDictionary *boards = [theData objectForKey:@"boards"];
    NSArray *boardArray = [self boardDictionaryToArray:boards];
    [self.windowController setBoardArrayContent:boardArray];
    NSString *boardName = [[boardArray objectAtIndex:0] valueForKey:@"name"];
    NSLog(@"boardName: %@", boardName);
    [self.windowController selectBoardNamed:boardName];
}

//how we set whether the menu items are avail or not.

//- (BOOL)validateMenuItem:(NSMenuItem*)menuItem
//{
//    return [XTModel currentWorkspaceDocument].workspace != nil;
//}

- (void)XTSetupTextViewContextMenuWithMenu:(id)arg1
{
    [(id)self originalSetupTextViewContextMenuWithMenu:arg1]; //call the original method (trust me, it does. haha)
    
    NSMenu *theMenu = (NSMenu *)arg1;
    NSMenuItem *trelloItem = [[NSMenuItem alloc] initWithTitle:@"Add Card to Trello..." action:@selector(newCardFromMenu:) keyEquivalent:@"c"];
    [trelloItem setKeyEquivalentModifierMask:NSControlKeyMask];
    NSInteger itemCount = [[theMenu itemArray] count];
   // NSLog(@"itemCount: %li", itemCount);
    [trelloItem setTarget:XTrelloSharedPlugin.windowController];
    [trelloItem setEnabled:TRUE];
    
    //idiot proofing, we dont want to be at the bottom of the menu. item 10 might still not be the best sweet spot. up for discussion.
    if (itemCount < 10)
    {
        [theMenu addItem:trelloItem];
    
    } else  {
        
        [theMenu insertItem:trelloItem atIndex:10];
    }
   
   // NSLog(@"orig: %@", orig);
   // NSLog(@"setupTextViewContextMenuWithMenu: %@", arg1);
    
   
}

- (id)newTextView:(id)arg1 menu:(id)arg2 forEvent:(id)arg3 atIndex:(unsigned long long)arg4
{
    NSLog(@"textView: %@ menu: %@ forEvent: %@ at index: %llu", arg1, arg2, arg3, arg4);
    
    NSMenu *orig = (NSMenu *)[self originalTextView:arg1 menu:arg2 forEvent:arg3 atIndex:arg4];
    
  
    NSMenuItem *testItem = [[NSMenuItem alloc] initWithTitle:@"science" action:@selector(newCardFromMenu:) keyEquivalent:@""];
    [orig addItem:testItem];
      NSLog(@"orig: %@", orig);
    return orig;
}

- (void)trelloDataUpdated:(NSDictionary *)theData
{
    if (self.windowController.boardsLoaded == false)
    {
        NSLog(@"boards are not loaded!");
        NSDictionary *boards = [theData objectForKey:@"boards"];
        NSArray *boardArray = [self boardDictionaryToArray:boards];
        [self.windowController setBoardArrayContent:boardArray];
        [self.windowController selectBoardNamed:[[boardArray objectAtIndex:0] valueForKey:@"name"]];
        self.windowController.boardsLoaded = TRUE;
    }
    trelloReady = TRUE;
    theData = trelloData;
    [self.windowController dataReloaded];
}

- (NSArray *)boardDictionaryToArray:(NSDictionary *)boardDict
{
    NSEnumerator *theEnum = [boardDict objectEnumerator];
    NSMutableArray *boardArray = [NSMutableArray new];
    id theObject = nil;
    while (theObject = [theEnum nextObject])
    {
        [boardArray addObject:theObject];
    }
  //  NSLog(@"boardArray: %@", boardArray);
    return boardArray;
}

- (void)trelloDataFetched:(NSDictionary *)theData
{
    trelloReady = TRUE;
    trelloData = theData;
    NSDictionary *boards = [theData objectForKey:@"boards"];
    NSArray *boardArray = [self boardDictionaryToArray:boards];
     if (self.windowController == nil) {
         XTWindowController* wc = [[XTWindowController alloc] initWithWindowNibName:@"XTWindowController"];
         self.windowController = wc;
         wc.delegate = self;
     }
    [self.windowController setBoardArrayContent:boardArray];
    self.windowController.boardsLoaded = TRUE;
    //[self.windowController.boardArrayController setContent:boardArray];
    [self.windowController selectBoardNamed:[[boardArray objectAtIndex:0] valueForKey:@"name"]];
    
    
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(_onNotifyProjectSettingChanged:)
//                                                 name:kXTrelloPreferencesChanged
//                                               object:nil];
    

    
    [self setupRefreshTimer];
    
    
}

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
    if (object == [NSUserDefaults standardUserDefaults]) {
        if ([keyPath isEqualToString:kXTrelloRefreshRate]) {
    
            [self setupRefreshTimer];
            
        } else if ([keyPath isEqualToString:kXTrelloAuthToken])
        {
            NSLog(@"change: %@", change);
            NSString *newSessionToken = change[NSKeyValueChangeNewKey];
            [[XTTrelloWrapper sharedInstance] setSessionToken:newSessionToken];
            [self refresh:nil];
            [self setupRefreshTimer];
        }
    }
}

- (void)refresh:(id)sender
{
    LOG_SELF;
    if ([[UD valueForKey:kXTrelloAuthToken] length] > 0 && [[UD valueForKey:kXTrelloAPIKey] length] > 0 )
        [[XTTrelloWrapper sharedInstance] reloadTrelloData];
    else
        NSLog(@"no auth token");
}

- (void)setupRefreshTimer
{
    LOG_SELF;
    if (refreshTimer != nil)
    {
        [refreshTimer invalidate];
        refreshTimer = nil;
    }
    
    NSInteger refreshRate = [[NSUserDefaults standardUserDefaults] integerForKey:kXTrelloRefreshRate];
    
    NSLog(@"refreshRate: %li",  (long)refreshRate);
    
    if (refreshRate == 0) return;
    
    
    refreshTimer = [NSTimer scheduledTimerWithTimeInterval:(refreshRate*60) target:self selector:@selector(refresh:) userInfo:nil repeats:TRUE];
    [[NSRunLoop currentRunLoop] addTimer:refreshTimer forMode:NSRunLoopCommonModes];
    
}

- (void)_onNotifyProjectSettingChanged:(NSNotification *)notification
{
    LOG_SELF;
    [self setupRefreshTimer];
    
}

- (void)addItemForWindowTag:(NSInteger)windowTag
{
    //1 = main, 2 = browser, 3 = prefs
    
    NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Window"];
    switch (windowTag) {
            
        case 1:
            
            xtrelloWindowMenuItem = [[menuItem submenu] itemWithTitle:@"Xtrello Cards"];
            if (xtrelloWindowMenuItem == nil)
                [[menuItem submenu] removeItem:xtrelloWindowMenuItem];
            
            break;
            
        case 2:
            
            xtrelloBrowserWindowMenuItem = [[menuItem submenu] itemWithTitle:@"Xtrello Browser"];
            if (xtrelloBrowserWindowMenuItem == nil)
            {
                xtrelloBrowserWindowMenuItem = [[NSMenuItem alloc] initWithTitle:@"Xtrello Browser" action:@selector(showBrowserWindow) keyEquivalent:@""];
                [[menuItem submenu] insertItem:xtrelloBrowserWindowMenuItem atIndex:14];
                [xtrelloBrowserWindowMenuItem setTarget:self];
            }
            
            break;
    }
}

// Sample Action, for menu item:
- (void)showTrelloWindow
{
    if (self.windowController.window.isVisible) {
        [self.windowController.window close];

    } else {
        if (self.windowController == nil) {
            XTWindowController* wc = [[XTWindowController alloc] initWithWindowNibName:@"XTWindowController"];
            self.windowController = wc;
            wc.delegate = self;
        }
        if (trelloData != nil)
        {
            NSDictionary *boards = [trelloData objectForKey:@"boards"];
            NSArray *boardArray = [self boardDictionaryToArray:boards];
            [self.windowController setBoardArrayContent:boardArray];
        }
        
        if ([UD valueForKey:kXTrelloAuthToken] == nil || [UD valueForKey:kXTrelloAPIKey] == nil)
        {
            NSLog(@"no auth token! show pref windows!");
            [self.windowController showPreferences:nil];
            return;
        }
        
        NSString *projectName = [XTModel currentProjectName];
        NSLog(@"projectname: %@", projectName);
        [self.windowController.window makeKeyAndOrderFront:nil];
        
        NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Window"];
        if (menuItem) {
        
            xtrelloWindowMenuItem = [[menuItem submenu] itemWithTitle:@"Xtrello Cards"];
            if (xtrelloWindowMenuItem == nil)
            {
                xtrelloWindowMenuItem = [[NSMenuItem alloc] initWithTitle:@"Xtrello Cards" action:@selector(showXtrelloWindow) keyEquivalent:@""];
                [[menuItem submenu] insertItem:xtrelloWindowMenuItem atIndex:13];
                [xtrelloWindowMenuItem setTarget:self];
            }
            
        }
      //  NSLog(@"currentProjectName: %@", [NSClassFromString(@"IDEWorkspaceWindowController") workspaceWindowControllers]);
     
        if (projectName != nil)
        {
            [self.windowController selectBoardNamed:projectName];
           // NSLog(@"firstResponder: %@", self.windowController.window.firstResponder);
            [self.windowController.window.firstResponder resignFirstResponder];
            //[self.windowController delayedResignFirstResponder];
            
        }
    }
}

- (void)showBrowserWindow
{
    [self.windowController.windowTwo makeKeyAndOrderFront:nil];
}

- (void)showXtrelloWindow
{
    [self.windowController.window makeKeyAndOrderFront:nil];
}

- (void) selectionDidChange:(NSNotification *)notification
{
    if ([[notification object] isKindOfClass:[NSTextView class]]) {
        
        self.windowController.currentTextView = (DVTSourceTextView *)[notification object];
        
        NSArray *selectedRanges = [self.windowController.currentTextView  selectedRanges];
        
        if (selectedRanges.count == 0) {
            return;
        }
        
       
        NSRange selectedRange = [[selectedRanges objectAtIndex:0] rangeValue];
        
          self.windowController.selectedLineRange = [self.windowController.currentTextView.textStorage.string lineRangeForRange:selectedRange];
        
        if ([ self.windowController.currentTextView respondsToSelector:@selector(_currentLineNumber)])
        {
            self.windowController.selectedLineNumber = [(DVTSourceTextView *)self.windowController.currentTextView  _currentLineNumber];
           // NSLog(@"line number: %lli", [(DVTSourceTextView *)self.currentTextView  _currentLineNumber]);
        }
        
        self.windowController.focalText = [self.windowController.currentTextView.textStorage.string substringWithRange:self.windowController.selectedLineRange];
        
    }
}

- (void)doNavbarScience
{
   // id workspaceWindow = [[NSApplication sharedApplication] keyWindow]; //IDEWorkspaceWindow
    //id firstResponder = [workspaceWindow firstResponder]; //DVTSourceTextView
    //NSLog(@"firstResponder: %@", firstResponder);
  //  id sourceCodeEditor = [firstResponder delegate]; //IDESourceCodeEditor
    id sourceCodeEditor = [XTModel currentEditor];
    DVTSourceTextView *sourceTextView = (DVTSourceTextView *)[sourceCodeEditor textView];
    long long lineNumber = [sourceTextView _currentLineNumber];
    NSLog(@"line number: %lli", lineNumber);
    id editorContext = [sourceCodeEditor valueForKey:@"editorContext"]; //IDEEditorContext
    //id navBar = [editorContext valueForKey:@"navBar"]; //IDENavBar
    id coord = [editorContext valueForKey:@"_navigableItemCoordinator"]; //IDENavigableItemCoordinator
    NSHashTable *coordinatedItems = [coord valueForKey:@"_coordinatedItems"]; //NSHashTable of IDEKeyDrivenNavigableItem
    NSArray *menuArray = [coordinatedItems allObjects];
    NSMutableArray *newNames = [[NSMutableArray alloc] init];
    NSLog(@"menuArray: %@", menuArray);
    for (id awesomeObject in menuArray)
    {
        DVTSourceLandmarkItem *repObject = [awesomeObject valueForKey:@"representedObject"];
      //  Class lndmkItem = NSClassFromString(@"DVTSourceLandmarkItem");
        NSLog(@"repObject: %@", repObject);
        if ([repObject respondsToSelector:@selector(range)])
        {
            NSString *rangeString = NSStringFromRange([repObject range]);
            NSString *name = repObject.name;
            NSDictionary *newDict = @{@"name": name, @"range": rangeString};
            if ([repObject numberOfChildren] > 0)
            {
                for (DVTSourceLandmarkItem *child in [repObject children])
                {
                    if ([child respondsToSelector:@selector(range)])
                    {
                        NSString *rangeString = NSStringFromRange([child range]);
                        NSString *name = child.name;
                        NSDictionary *newDict2 = @{@"name": name, @"range": rangeString};
                        [newNames addObject:newDict2];
                    }
                }
            }
            [newNames addObject:newDict];
        }
      
    }
    
    NSLog(@"newNames: %@", newNames);
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
