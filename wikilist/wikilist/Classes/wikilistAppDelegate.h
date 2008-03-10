//
//  wikilistAppDelegate.h
//  wikilist
//
//  Created by Matthew Sachs on 2008-03-08.
//  Copyright __MyCompanyName__ 2008. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FileListController;
@interface wikilistAppDelegate : NSObject  <UIApplicationDelegate, UINavigationBarDelegate, UIModalViewDelegate> {
    UIWindow *window;
    FileListController *fileList;
	UINavigationController *navController;
}

@property (nonatomic, retain) UIWindow *window;

+ (wikilistAppDelegate *)sharedController;
- (void)addNewPage;
- (void)cancelNewPage:(id)sender;
- (void)createPage:(NSString *)pageName asToDoList:(BOOL)isToDoList;
- (BOOL)pageExists:(NSString *)pageName;
- (NSString *)pageLastViewed;
- (void)setPageLastViewed:(NSString *)page;

@end
