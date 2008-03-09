//
//  FileListController.m
//  wikilist
//
//  Created by Matthew Sachs on 2008-03-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "FileListController.h"
#import "PageController.h"

@implementation FileListController

- (NSString *)_getNoteDir {
	return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]
				stringByAppendingPathComponent:@"wikilist"];
}

- (void)_getNotes {
	[paths release];
	NSString *dir = [self _getNoteDir];
	paths = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil] mutableCopy];
	if(!paths) {
		[[NSFileManager defaultManager]
			createDirectoryAtPath:dir
			withIntermediateDirectories:YES
			attributes:nil
			error:nil];
		paths = [[NSMutableArray alloc] init];
	}
}

- (id)init
{
	if (self = [super init]) {
		self.title = @"Pages";
		[self _getNotes];
	}
	return self;
}


- (void)loadView
{
	// Set up table view
    tableView = [[UITableView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame] style:UITableViewStylePlain];
	tableView.delegate = self;
	tableView.dataSource = self;
	tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
	self.view = tableView;
	[tableView release];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	// Return YES for supported orientations.
	return YES;
	//return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview.
	// Release anything that's not essential, such as cached data.
	[paths release];
	paths = nil;
}

- (void)dealloc
{
	[paths release];
	[super dealloc];
}

- (void)addNewPage {
	NSString *name = @"Untitled Page";
	int suffix = 0;
	while([paths containsObject:name]) {
		name = [NSString stringWithFormat:@"Untitled Page %d", ++suffix];
	}
	
	[paths addObject:name];
	[@"" writeToFile:[[self _getNoteDir] stringByAppendingPathComponent:name] atomically:NO];
	[tableView reloadData];
}
- (NSString *)lastPage { return [paths lastObject]; }
- (NSString *)selectedPage { return [paths objectAtIndex:0]; }
- (void)reloadData { [tableView reloadData]; }
- (PageController *)pageControllerForPage:(NSString *)page {
	if(![paths containsObject:page]) return nil;
	return [[[PageController alloc] initWithName:page directory:[self _getNoteDir]] autorelease];
}
- (NSString *)pageBeingViewed { return [[NSUserDefaults standardUserDefaults] objectForKey:@"Page"]; }
- (void)loadPage:(NSString *)page {
	PageController *pageController = [self pageControllerForPage:page];
	if(pageController) {
		[[NSUserDefaults standardUserDefaults] setObject:page forKey:@"Page"];
		[[self navigationController] pushViewController:pageController animated:YES];
	}
}



- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if(!paths) [self _getNotes];
	return [paths count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath withAvailableCell:(UITableViewCell *)availableCell {
	UISimpleTableViewCell *cell = nil;

	if (availableCell != nil) {
		cell = (UISimpleTableViewCell *)availableCell;
	} else {
		CGRect frame = CGRectMake(0, 0, 300, 44);
		cell = [[[UISimpleTableViewCell alloc] initWithFrame:frame] autorelease];
	}
	if(!paths) [self _getNotes];
	cell.text = [paths objectAtIndex:[indexPath row]];
	return cell;
}

- (void)tableView:(UITableView *)tableView selectionDidChangeToIndexPath:(NSIndexPath *)newIndexPath fromIndexPath:(NSIndexPath *)oldIndexPath {
	[self loadPage:[paths objectAtIndex:newIndexPath.row]];
}

@end
