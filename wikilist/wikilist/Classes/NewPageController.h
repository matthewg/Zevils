//
//  NewPageController.h
//  wikilist
//
//  Created by Matthew Sachs on 2008-03-09.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface NewPageController : UIViewController <UITableViewDelegate, UITableViewDataSource> {
	NSString *pageName;
	BOOL isToDoList;
	UIButton *createButton;
}

@end
