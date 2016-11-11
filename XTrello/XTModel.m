//
//  XTModel.m
//  XToDo
//
//  Created by Travis on 13-11-28.
//  Copyright (c) 2013年 Plumn LLC. All rights reserved.
//

#import "XTModel.h"
#import <objc/runtime.h>

//#import "XToDoPreferencesWindowController.h"

#import "NSData+Split.h"
#import "XTrello.h"

static NSBundle *pluginBundle;

//@class XTrello;
@implementation XTModel

+ (NSString *)applicationSupportFolder
{
    NSBundle *ourBundle = [NSBundle bundleForClass:objc_getClass("XTrello")];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    basePath = [basePath stringByAppendingPathComponent:[[ourBundle infoDictionary] objectForKey:(NSString *)kCFBundleNameKey]];
    if (![[NSFileManager defaultManager] fileExistsAtPath:basePath])
        [[NSFileManager defaultManager] createDirectoryAtPath:basePath withIntermediateDirectories:YES attributes:nil error:nil];
    
    return basePath;
}

+ (NSString *)boardsDataStoreFile
{
    return [[self applicationSupportFolder] stringByAppendingPathComponent:@"trelloBoards.plist"];
}

//currently unused, SHOULD get an nsdictionary of commit items.

+ (NSArray *)logEntries
{
    
    // git log --pretty="%ad COMMIT_MSG: %s" --since=1.day --date=short
    /*
     
     will yield something that can be parsed easier, has less of a footprint, and less overhead:
     
     
     2016-11-10 - expanded out all of the umbrella categories that were lazily stored in UIView+RecursiveFind into their own individual respective classes
     2016-11-09 - added predicate category that could potentially help for more complex filtering in the future
     2016-11-09 - refactored a slew of categories out of NSDate into their own respective files, still need to do the same to UIView+RecursiveFind next
     
     
     
     */
    
    NSArray *commitArray = [XTModel returnFromGITWithArguments:@[@"log", @"--pretty=\"%ad COMMIT_MSG: %s\"",@"--since=1.day", @"--date=short"]];
    //NSArray *logArray = [XTModel returnFromGITWithArguments:@[@"--no-pager", @"log", @"--date=short"]];
    NSDateFormatter *tf = [NSDateFormatter new];
    //EEE, MMM d, ''yy	Wed, July 10, '96
    //Tue Nov 8 17:50:32 2016
    //@"[EEE MMM d HH:mm:ss yyyy
    [tf setDateFormat:@"yyyy-MM-dd"];
   // return [[logArray componentsJoinedByString:@"\n"] componentsSeparatedByString:@"commit"];
   // NSArray *commitArray = [[logArray componentsJoinedByString:@"\n"] componentsSeparatedByString:@"commit"];
    
    __block NSMutableArray *finalArray = [[NSMutableArray alloc] init];
    [commitArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
        NSMutableDictionary *commitDict = [NSMutableDictionary new];
        NSArray *items = [[obj stringByReplacingOccurrencesOfString:@"\"" withString:@""] componentsSeparatedByString:@"COMMIT_MSG: "];
        if ([items count] == 2)
        {
            NSString *dateString = [items[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSDate *theDate = [tf dateFromString:dateString];
            commitDict[@"date"] = theDate;
            commitDict[@"comment"]  = items[1];
            [finalArray addObject:commitDict];
        }
    }];
    /*
    [commitArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
        NSMutableDictionary *commitDict = [NSMutableDictionary new];
        NSMutableArray *itemArray = [[obj componentsSeparatedByString:@"\n"] mutableCopy];
        [itemArray removeObject:@""];
        //  NSLog(@"itemArray: %@ count: %lu", itemArray, itemArray.count);
        if (itemArray.count >= 4)
        {
            
            NSString *dateString = [[[itemArray[2] componentsSeparatedByString:@"Date:"] lastObject] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            NSDate *theDate = [tf dateFromString:dateString];
            
            //  NSLog(@"date string: -%@- date: %@", dateString, theDate);
            
            commitDict[@"commit"] = [itemArray[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            commitDict[@"author"] = [[[itemArray[1] componentsSeparatedByString:@":"] lastObject] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            commitDict[@"date"] = theDate;
            commitDict[@"comment"] = [itemArray[3] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            [finalArray addObject:commitDict];
            
        }
        
    }];
     */
    return finalArray;
}

+ (NSPredicate *)todayPredicate
{
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDate *today = [NSDate date];
    NSDateComponents *toDateComponents = [calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate:today];
    NSDate *beginning = [calendar dateFromComponents:toDateComponents];
    return [NSPredicate predicateWithFormat:@"date >= %@ && date <= %@", beginning, today];
}


+ (NSString *)todaysEntriesTrelloDescriptionExcludingDescription:(NSString *)desc
{
    NSArray *descArray = [desc componentsSeparatedByString:@"\n"];
    NSLog(@"descArray: %@", descArray);
    NSArray *todayArray = [[self logEntries] filteredArrayUsingPredicate:[self todayPredicate]];
    __block NSMutableString *newString = [NSMutableString new];
    if (descArray.count > 0)
    {
        [newString appendFormat:@"%@\n",desc];
    }
    [todayArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
       NSLog(@"comment: %@", obj[@"comment"]);
        
        NSString *commentCheck = [NSString stringWithFormat:@"- %@", obj[@"comment"]];
       
        if (![descArray containsObject:commentCheck])
        {
            [newString appendFormat:@"- %@\n", obj[@"comment"]];
        } else {
            NSLog(@"#### comment already exists!");
        }
        
        
    }];
    return newString;
}


+ (NSString *)currentGITBranch
{
    NSString *currentBranch = nil;
    NSArray *branchArray = [self returnFromGITWithArguments:[NSArray arrayWithObjects:@"branch", @"--list", nil]];
    for (NSString *branchItem in branchArray)
    {
        if ([branchItem rangeOfString:@"*"].location != NSNotFound)
            currentBranch = [branchItem substringFromIndex:2];
    }
    return currentBranch;
}

+ (NSArray *)returnFromGITWithArguments:(NSArray *)gitArguments
{
    NSString *rootPath = [XTModel currentRootPath];
    return [XTModel returnFromCommand:@"/usr/bin/git" withArguments:gitArguments inPath:rootPath];
}

+ (NSArray *)returnFromCommand:(NSString *)commandBinary withArguments:(NSArray *)commandArguments inPath:(NSString *)thePath
{
    NSTask *mnt = [[NSTask alloc] init];
    NSPipe *pip = [[NSPipe alloc] init];;
    NSFileHandle *handle = [pip fileHandleForReading];
    NSData *outData;
    [mnt setCurrentDirectoryPath:thePath];
    [mnt setLaunchPath:commandBinary];
    [mnt setArguments:commandArguments];
    [mnt setStandardError:pip];
    [mnt setStandardOutput:pip];
    [mnt launch];
    
    NSString *temp;
    NSMutableArray *lineArray = [[NSMutableArray alloc] init];
    while((outData = [handle readDataToEndOfFile]) && [outData length])
    {
        temp = [[NSString alloc] initWithData:outData encoding:NSASCIIStringEncoding];
        [lineArray addObjectsFromArray:[temp componentsSeparatedByString:@"\n"]];
    }
    temp = nil;
    if ([lineArray count] ==0)
    {
        return [NSArray arrayWithObject:@""]; //idiot proofing
    }
    return lineArray;
}

+ (IDEWorkspaceTabController*)tabController{
    NSWindowController *currentWindowController = [[NSApp keyWindow] windowController];
    
    if ([currentWindowController isKindOfClass:NSClassFromString(@"XTWindowController")])
    {
        currentWindowController = [XTrello prevWindowController];
    }
    
    if ([currentWindowController isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
        IDEWorkspaceWindowController *workspaceController = (IDEWorkspaceWindowController *)currentWindowController;
        
        return workspaceController.activeWorkspaceTabController;
    }
    return nil;
}

+ (id)currentEditor {
    NSWindowController *currentWindowController = [[NSApp mainWindow] windowController];
    
    if ([currentWindowController isKindOfClass:NSClassFromString(@"XTWindowController")])
    {
        currentWindowController = [XTrello prevWindowController];
    }
    
    if ([currentWindowController isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
        IDEWorkspaceWindowController *workspaceController = (IDEWorkspaceWindowController *)currentWindowController;
        IDEEditorArea *editorArea = [workspaceController editorArea];
        IDEEditorContext *editorContext = [editorArea lastActiveEditorContext];
        return [editorContext editor];
    }
    return nil;
}
+ (IDEWorkspaceDocument *)currentWorkspaceDocument {
    NSWindowController *currentWindowController = [[NSApp mainWindow] windowController];
    NSLog(@"cwc: %@", currentWindowController);
    
    if ([currentWindowController isKindOfClass:NSClassFromString(@"XTWindowController")])
    {
        currentWindowController = [XTrello prevWindowController];
    }
    
    id document = [currentWindowController document];
    if (currentWindowController && [document isKindOfClass:NSClassFromString(@"IDEWorkspaceDocument")]) {
        return (IDEWorkspaceDocument *)document;
    }
    return nil;
}

+ (IDESourceCodeDocument *)currentSourceCodeDocument {
    
    IDESourceCodeEditor *editor=[self currentEditor];
    
    if ([editor isKindOfClass:NSClassFromString(@"IDESourceCodeEditor")]) {
        return editor.sourceCodeDocument;
    }
    
    if ([editor isKindOfClass:NSClassFromString(@"IDESourceCodeComparisonEditor")]) {
        if ([[(IDESourceCodeComparisonEditor*)editor primaryDocument] isKindOfClass:NSClassFromString(@"IDESourceCodeDocument")]) {
            return (id)[(IDESourceCodeComparisonEditor *)editor primaryDocument];
        }
    }
    
    return nil;
}

+ (IDESourceControlWorkspaceMonitor *)sourceControlMonitor
{
    return [XTModel currentWorkspaceDocument].workspace.sourceControlWorkspaceMonitor;
    
}

//TESTME: some tests!
/*
+ (NSString*)scannedStrings {
    NSArray* prefsStrings = [[NSUserDefaults standardUserDefaults] objectForKey:kXToDoTagsKey];
    NSMutableArray* escapedStrings = [NSMutableArray arrayWithCapacity:[prefsStrings count]];
    
    for (NSString* origStr in prefsStrings) {
        NSMutableString* str = [NSMutableString string];
        
        for (NSUInteger i=0; i<[origStr length]; i++) {
            unichar c = [origStr characterAtIndex:i];
            
            if (!isalpha(c) && ! isnumber(c)) {
                [str appendFormat:@"\\%C", c];
            } else {
                [str appendFormat:@"%C", c];
            }
        }
        
        [str appendFormat:@"\\:"];
        
        [escapedStrings addObject:str];
    }
    
    return [escapedStrings componentsJoinedByString:@"|"];
}
*/

typedef void(^OnFindedItem)(NSString *fullPath, BOOL isDirectory,  BOOL *skipThis, BOOL *stopAll);
+ (void) scanFolder:(NSString*)folder findedItemBlock:(OnFindedItem)findedItemBlock
{
    BOOL stopAll = NO;
    
    NSFileManager* localFileManager = [[NSFileManager alloc] init];
    NSDirectoryEnumerationOptions option = NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsPackageDescendants;
    NSDirectoryEnumerator* directoryEnumerator = [localFileManager enumeratorAtURL:[NSURL fileURLWithPath:folder]
                                                        includingPropertiesForKeys:nil
                                                                           options:option
                                                                      errorHandler:nil];
    for (NSURL* theURL in directoryEnumerator)
    {
        if (stopAll)
        {
            break;
        }
        
        NSString *fileName = nil;
        [theURL getResourceValue:&fileName forKey:NSURLNameKey error:NULL];
        
        NSNumber *isDirectory = nil;
        [theURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];
        
        BOOL skinThis = NO;
        
        BOOL directory = [isDirectory boolValue];
        
        findedItemBlock([theURL path], directory, &skinThis, &stopAll);
        
        if (skinThis)
        {
            [directoryEnumerator skipDescendents];
        }
    }
}


+ (NSArray *)removeSubDirs:(NSArray*)dirs
{
    // TODO:
    return dirs;
}

+ (NSSet *)lowercaseFileTypes:(NSSet *)fileTypes
{
    NSMutableSet *set = [NSMutableSet setWithCapacity:[fileTypes count]];
    for (NSString * fileType in fileTypes)
    {
        [set addObject:[fileType lowercaseString]];
    }
    return set;
}

+ (NSArray*)findFileNameWithProjectPath:(NSString *)projectPath
                            includeDirs:(NSArray *)includeDirs
                            excludeDirs:(NSArray *)excludeDirs
                              fileTypes:(NSSet *)fileTypes
{
    includeDirs = [XTModel explandRootPathMacros:includeDirs projectPath:projectPath];
    includeDirs = [XTModel removeSubDirs:includeDirs];
    excludeDirs = [XTModel explandRootPathMacros:excludeDirs projectPath:projectPath];
    excludeDirs = [XTModel removeSubDirs:excludeDirs];
    fileTypes   = [XTModel lowercaseFileTypes:fileTypes];
    NSMutableArray *allFilePaths = [NSMutableArray arrayWithCapacity:1000];
    for (NSString *includeDir in includeDirs)
    {
        [XTModel scanFolder:includeDir findedItemBlock:^(NSString *fullPath, BOOL isDirectory, BOOL *skipThis, BOOL *stopAll) {
            if (isDirectory)
            {
                for (NSString *excludeDir in excludeDirs)
                {
                    if ([fullPath hasPrefix:excludeDir])
                    {
                        *skipThis = YES;
                        return;
                    }
                }
            }
            else
            {
                if ([fileTypes containsObject:[[fullPath pathExtension] lowercaseString]])
                {
                    [allFilePaths addObject:fullPath];
                }
            }
            
        }];
    }
    return allFilePaths;
}




+ (NSString *) _settingDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    // TODO [path count] == 0
    NSString *settingDirectory = [(NSString *)[paths objectAtIndex:0] stringByAppendingPathComponent:@"GMDeploy"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:settingDirectory] == NO)
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:settingDirectory
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    }
    return settingDirectory;
}

+ (NSString *) _tempFileDirectory
{
    NSString *tempFileDirectory = [[XTModel _settingDirectory] stringByAppendingPathComponent:@"Temp"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:tempFileDirectory] == NO)
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:tempFileDirectory
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    }
    return tempFileDirectory;
}

+ (void) cleanAllTempFiles
{
    [XTModel scanFolder:[XTModel _tempFileDirectory] findedItemBlock:^(NSString *fullPath, BOOL isDirectory, BOOL *skipThis, BOOL *stopAll) {
        [[NSFileManager defaultManager] removeItemAtPath:fullPath error:nil];
    }];
}

+ (NSString *)currentProjectName
{
    NSString *filePath = [XTModel currentWorkspaceDocument].workspace.name;
    //NSString *projectDir= [filePath stringByDeletingLastPathComponent];
    return filePath;
}

+ (NSString *)currentProjectFile
{
    NSString *filePath = [[XTModel currentWorkspaceDocument].workspace.representingFilePath.fileURL path];
    //NSString *projectDir= [filePath stringByDeletingLastPathComponent];
    return filePath;
}

+ (NSString *)currentRootPath
{
    NSString *filePath = [[XTModel currentWorkspaceDocument].workspace.representingFilePath.fileURL path];
    return [filePath stringByDeletingLastPathComponent];
}

+ (NSString *) rootPathMacro
{
    return [XTModel addPathSlash:@"$(SRCROOT)"];
}

+ (NSArray *) explandRootPathMacros:(NSArray *)paths projectPath:(NSString *)projectPath
{
    if (projectPath == nil)
    {
        return paths;
    }
    
    NSMutableArray *explandPaths = [NSMutableArray arrayWithCapacity:[paths count]];
    for (NSString *path in paths) {
        [explandPaths addObject:[XTModel explandRootPathMacro:path projectPath:projectPath]];
    }
    return explandPaths;
}

+ (NSString *) addPathSlash:(NSString *)path
{
    if ([path length] > 0)
    {
        if ([path characterAtIndex:([path length] - 1)] != '/')
        {
            path = [NSString stringWithFormat:@"%@/", path];
        }
    }
    return path;
}

+ (NSString *) explandRootPathMacro:(NSString *)path projectPath:(NSString *)projectPath
{
    projectPath = [XTModel addPathSlash:projectPath];
    path = [path stringByReplacingOccurrencesOfString:[XTModel rootPathMacro] withString:projectPath];
    
    return [XTModel addPathSlash:path];
}

+ (NSString *) settingFilePathByProjectName:(NSString *)projectName
{
    NSString *settingDirectory = [XTModel _settingDirectory];
    NSString *fileName = [projectName length] ? projectName : @"Test.xcodeproj";
    return [settingDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist",fileName]];
}



+ (XTProjectSetting *) projectSettingByProjectName:(NSString *)projectName
{
    static NSMutableDictionary *projectName2ProjectSetting = nil;
    if (projectName2ProjectSetting == nil)
    {
        projectName2ProjectSetting = [[NSMutableDictionary alloc] init];
    }
    
    if (projectName != nil)
    {
        id object = [projectName2ProjectSetting objectForKey:projectName];
        if ([object isKindOfClass:[XTProjectSetting class]])
        {
            return object;
        }
    }
    
    NSString *fullPath = [XTModel settingFilePathByProjectName:projectName];
    XTProjectSetting *projectSetting = nil;
    @try {
        projectSetting = [NSKeyedUnarchiver unarchiveObjectWithFile:fullPath];
    }
    @catch (NSException *exception) {
    }
    if ([projectSetting isKindOfClass:[projectSetting class]] == NO){
        projectSetting = nil;
    }
    
    if (projectSetting == nil) {
        projectSetting = [XTProjectSetting defaultProjectSetting];
    }
    if ((projectSetting != nil) && (projectName != nil))
    {
        [projectName2ProjectSetting setObject:projectSetting forKey:projectName];
    }
    return projectSetting;
}

+ (void) saveProjectSetting:(XTProjectSetting *)projectSetting ByProjectName:(NSString *)projectName
{
    if (projectSetting == nil)
    {
        return;
    }
    @try {
        NSString *filePath = [XTModel settingFilePathByProjectName:projectName];
        [NSKeyedArchiver archiveRootObject:projectSetting
                                    toFile:filePath];
        filePath = nil;
    }
    @catch (NSException *exception) {
        NSLog(@"saveProjectSetting:exception:%@", exception);
    }
    NSLog(@"haha");
}

@end
