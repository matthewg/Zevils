//
//  PageController.h
//  wikilist
//
//  Created by Matthew Sachs on 2008-03-09.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface PageController : UIViewController {
	NSString *name;
	NSString *directory;
	NSString *fileName;
}

- (id)initWithName:(NSString *)_name directory:(NSString *)_directory;

@end
