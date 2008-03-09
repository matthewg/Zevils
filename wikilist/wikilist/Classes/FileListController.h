//
//  FileListController.h
//  wikilist
//
//  Created by Matthew Sachs on 2008-03-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PageController;
@interface FileListController : UIViewController <UITableViewDelegate, UITableViewDataSource> {
	NSMutableArray *paths;
	UITableView *tableView;
}

- (void)addNewPage;
- (NSString *)lastPage;
- (NSString *)selectedPage;
- (void)reloadData;
- (PageController *)pageControllerForPage:(NSString *)page;
- (NSString *)pageBeingViewed;
- (void)loadPage:(NSString *)page;

@end
