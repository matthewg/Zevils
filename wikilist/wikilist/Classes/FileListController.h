//
//  FileListController.h
//  wikilist
//
//  Created by Matthew Sachs on 2008-03-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PageController;
@class wikilistAppDelegate;
@interface FileListController : UIViewController <UITableViewDelegate, UITableViewDataSource> {
	NSMutableArray *pages;
	NSMutableDictionary *pageProperties;
	NSMutableDictionary *pagesAndProperties;
	UITableView *tableView;
}

- (void)addPageNamed:(NSString *)name asToDoList:(BOOL)isToDoList;
- (void)reloadData;
- (PageController *)pageControllerForPage:(NSString *)page;
- (void)loadPage:(NSString *)page;
- (BOOL)pageExists:(NSString *)page;

@end
