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

@end
