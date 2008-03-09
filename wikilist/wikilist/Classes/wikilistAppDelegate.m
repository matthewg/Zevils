//
//  wikilistAppDelegate.m
//  wikilist
//
//  Created by Matthew Sachs on 2008-03-08.
//  Copyright __MyCompanyName__ 2008. All rights reserved.
//

#import "wikilistAppDelegate.h"
#import "FileListController.h"
#import "PageController.h"

@implementation wikilistAppDelegate

@synthesize window;


- init {
	if (self = [super init]) {
	}
	return self;
}

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    // Create window
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
	
	/*NSMutableArray *toolbarItems = [[NSMutableArray alloc] initWithCapacity:3];
	UIToolbarItem *toolbarItem;

	toolbarItem = [[UIToolbarItem alloc] initWithSystemItem:UIToolbarSystemItemNew target:self action:@selector(makeNew:)];
	[toolbarItems addObject:toolbarItem];
	[toolbarItem release];*/

	/* Main panel:       (*prefs*) (*sync*) (*add*)
	      List of notes: UITableView
	   Note panel: (UIButtonTypeNavigationBack)   Title   (*sync*) (*add)
			UITextView
	*/
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObject:@"" forKey:@"Page"]];
	
	fileList = [[FileListController alloc] init];
	navController = [[UINavigationController alloc] initWithRootViewController:fileList];
	
	UISegmentedControl *buttons = [[UISegmentedControl alloc]
		initWithItems:[NSArray arrayWithObjects:@"*", @"@", @"+", nil]];
	buttons.segmentedControlStyle = UISegmentedControlStyleBar;
	buttons.momentary = YES;
	[buttons addTarget:self action:@selector(clickedButton:) forControlEvents:UIControlEventValueChanged];

	navController.topViewController.navigationItem.customRightView = buttons;

	//CGSize imageSize = CGSizeMake(100, 46);
	//fileListController.toolbarItem.image = ...;
	//[viewControllers addObject:fileList];
	
    // Show the window with table view
	//toolbar.items = toolbarItems;
	//[toolbarItems release];
	[window addSubview:navController.view];
    [window makeKeyAndVisible];
	[fileList reloadData];

	NSString *loadPage = [fileList pageBeingViewed];
	NSLog(@"Got default page: %@", loadPage);
	if(![loadPage isEqualToString:@""]) {
		[fileList loadPage:loadPage];
	}
}

- (void)dealloc {
	[navController release];
    [window release];
    [super dealloc];
}

- (void)clickedButton:(id)sender {
	UISegmentedControl *buttons = sender;

	switch(buttons.selectedSegmentIndex) {
		case 0:
			//Prefs
			break;
		case 1:
			//Sync
			break;
		case 2:
			//Add
			[fileList addNewPage];
			[self _loadPage:[fileList lastPage]];
			
			break;
	}
}

@end
