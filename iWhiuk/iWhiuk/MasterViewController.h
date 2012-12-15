//
//  MasterViewController.h
//  iWhiuk
//
//  Created by Richard Whitehouse on 11/12/2012.
//  Copyright (c) 2012 Richard Whitehouse. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DetailViewController;

#import <CoreData/CoreData.h>

@interface MasterViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (strong, nonatomic) DetailViewController *detailViewController;

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

- (void)refresh:(id)sender;

@end
