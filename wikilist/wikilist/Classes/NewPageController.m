//
//  NewPageController.m
//  wikilist
//
//  Created by Matthew Sachs on 2008-03-09.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "NewPageController.h"
#import "NewPageNameCell.h"
#import "NewPageTypeCell.h"
#import "wikilistAppDelegate.h"

@implementation NewPageController

- (id)init
{
	if (self = [super init]) {
		// Initialize your view controller.
		self.title = @"New Page";
	}
	return self;
}

- (void)loadView
{
	//[Cancel]  ...   [Create]
	//Grouped table view with one group containing:
	//   Name   {text}
	//   To-Do List?    {YES/NO}

	// Create a custom view hierarchy.
	UITableView *view = [[UITableView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame] style:UITableViewStyleGrouped];
	view.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
	view.delegate = self;
	view.dataSource = self;
	self.view = view;
	[view release];
	
	UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeNavigation];
	[cancelButton setTitle:@"Cancel" forStates:UIControlStateNormal];
	self.navigationItem.customLeftView = cancelButton;
	[cancelButton
		addTarget:[wikilistAppDelegate sharedController]
		action:@selector(cancelNewPage:)
		forControlEvents:UIControlEventTouchUpInside];

	createButton = [UIButton buttonWithType:UIButtonTypeNavigation];
	[createButton setTitle:@"Create" forStates:UIControlStateNormal];
	createButton.enabled = NO;
	[createButton addTarget:self action:@selector(create:) forControlEvents:UIControlEventTouchUpInside];
	self.navigationItem.customRightView = createButton;
}

- (void)create:(id)sender {
	[[wikilistAppDelegate sharedController]
		createPage:pageName
		asToDoList:isToDoList];
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
}

- (void)dealloc
{
	[pageName release];
	[super dealloc];
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath withAvailableCell:(UITableViewCell *)availableCell {
	CGRect frame = CGRectMake(0, 0, 300, 44);

	if([indexPath row] == 0) {
		return [[[NewPageNameCell alloc] initWithFrame:frame target:self action:@selector(textChanged:)] autorelease];
	} else {
		return [[[NewPageTypeCell alloc] initWithFrame:frame target:self action:@selector(switchedType:)] autorelease];
	}
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	return nil;
}

- (void)textChanged:(UITextField *)sender {
	[pageName release];
	pageName = [sender.text retain];
	createButton.enabled = pageName && ![pageName isEqualToString:@""] && ![[wikilistAppDelegate sharedController] pageExists:pageName];
}

- (void)switchedType:(UISwitch *)sender {
	isToDoList = sender.on;
}

@end
