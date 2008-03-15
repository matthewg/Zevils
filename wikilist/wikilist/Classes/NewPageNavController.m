//
//  NewPageNavController.m
//  wikilist
//
//  Created by Matthew Sachs on 2008-03-15.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "NewPageNavController.h"
#import "NewPageController.h"

@implementation NewPageNavController

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
	NewPageController *npc = [[NewPageController alloc] init];
	navController = [[UINavigationController alloc] initWithRootViewController:npc];
	[npc release];
	self.view = navController.view;
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
	[navController release];
	[super dealloc];
}


@end
