//
//  NewPageNameCell.h
//  wikilist
//
//  Created by Matthew Sachs on 2008-03-09.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface NewPageNameCell : UITableViewCell <UITextFieldDelegate> {
	UILabel *label;
	UITextField *text;
}

- (id)initWithFrame:(CGRect)frame target:(id)target action:(SEL)action;

@end
