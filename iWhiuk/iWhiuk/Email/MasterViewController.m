//
//  MasterViewController.m
//  iWhiuk
//
//  Created by Richard Whitehouse on 11/12/2012.
//  Copyright (c) 2012 Richard Whitehouse. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AppDelegate.h"
#import "MasterViewController.h"
#import "DetailViewController.h"
#import "Settings.h"

@interface MasterViewController ()
{
  NSMutableArray *connections;
  NSMutableArray *markAsReadConnnections;
  NSMutableData *receivedData;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
@end

@implementation MasterViewController

- (void)awakeFromNib
{
  if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
      self.clearsSelectionOnViewWillAppear = NO;
      self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
  }
    [super awakeFromNib];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.
  
  connections = [[NSMutableArray alloc] init];
  markAsReadConnnections = [[NSMutableArray alloc] init];
  receivedData = nil;

  UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh:)];
  self.navigationItem.rightBarButtonItem = refreshButton;
  self.detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self refresh: nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)refresh:(id)sender
{
  
  NSURL* refreshURL = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@/mail/new", SERVER]];
  
  NSMutableURLRequest *URLRequest = [[NSMutableURLRequest alloc] init];
  
  [URLRequest setURL:refreshURL];
  [URLRequest setHTTPMethod:@"GET"];
  [URLRequest setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
  [URLRequest setTimeoutInterval:20.0];
  
  // Initiate the URL load.
  NSURLConnection *URLConn = [[NSURLConnection alloc] initWithRequest:URLRequest
                                                             delegate:self
                                                     startImmediately:NO];
  
  receivedData = [[NSMutableData alloc] init];
  
  NSLog(@"Length of connections: %@ %u", connections, [connections count]);
  
  [connections addObject: URLConn];
  
  NSLog(@"Length of connections: %@ %u", connections, [connections count]);
  
  [URLConn start];
}

- (void)connection:(NSURLConnection *)xiConnection didReceiveData:(NSData *)data
{
  NSLog(@"Received data");
  NSLog(@"Length of connections: %u", [connections count]);
  for(NSURLConnection* connection in connections)
  {
    NSLog(@".. checking connection");
    if(connection == xiConnection)
    {
      NSLog(@".... on connection");
      [receivedData appendData:data];
    }
  }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
  NSLog(@"%@", error);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)xiConnection
{
  for(NSURLConnection* connection in markAsReadConnnections)
  {
    if(connection == xiConnection)
    {
      [self refresh:nil];
      [markAsReadConnnections removeObject:connection];
    }
  }
  
  NSLog(@"Finished receiving data");
  NSLog(@"Length of connections: %u", [connections count]);
  
  for(NSURLConnection* connection in connections)
  {
    NSLog(@".. checking connection");
    if(connection == xiConnection)
    {
      NSLog(@".... on connection");
      [connections removeObject:xiConnection];
      NSError* error;
      id data = [NSJSONSerialization JSONObjectWithData:receivedData options:0 error:&error];
      if([data isKindOfClass: [NSArray class]])
      {
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        NSEntityDescription *entity = [[self.fetchedResultsController fetchRequest] entity];
        
        NSMutableArray* found = [[NSMutableArray alloc] init];
        
        NSArray* messages = (NSArray*) data;
        for (NSDictionary* message in messages)
        {
          NSString* path = [NSString stringWithFormat:@"%@/%@", [message objectForKey:@"mailbox"], [message objectForKey:@"message"]];
          
          [found addObject:path];
          
          NSFetchRequest* fr = [[NSFetchRequest alloc] initWithEntityName:[entity name]];
          [fr setPredicate:[NSPredicate predicateWithFormat:@"path == %@", path]];
          
          NSError *error = nil;
          NSArray* matches = [context executeFetchRequest:fr error:&error];
          if(error != nil)
          {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
          }
          
          if([matches count] == 0)
          {
            NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:[entity name] inManagedObjectContext:context];
            
            // If appropriate, configure the new managed object.
            // Normally you should use accessor methods, but using KVC here avoids the need to add a custom class to the template.
            
            NSNumber* number = [message objectForKey:@"time"];
            
            [newManagedObject setValue:[NSDate dateWithTimeIntervalSince1970: [number unsignedIntegerValue]]
                                forKey:@"time"];
            [newManagedObject setValue:path forKey:@"path"];
            [newManagedObject setValue:[message objectForKey:@"subject"] forKey:@"subject"];
          }
        }
        
        // Delete missing objects
        
        NSFetchRequest* fr = [[NSFetchRequest alloc] initWithEntityName:[entity name]];
        [fr setPredicate:[NSPredicate predicateWithFormat:@"NOT path IN %@", found]];
        
        NSError *error = nil;
        NSArray* matches = [context executeFetchRequest:fr error:&error];
        if(error != nil)
        {
          // Replace this implementation with code to handle the error appropriately.
          // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
          NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
          abort();
        }
        
        for(NSManagedObject* obj in matches)
        {
          [context deleteObject:obj];
        }
        
        // Save the context.
        if (![context save:&error]) {
          // Replace this implementation with code to handle the error appropriately.
          // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
          NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
          abort();
        }
      }
    }
  }
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
  return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
      
      NSString* path = [[[self.fetchedResultsController objectAtIndexPath:indexPath] valueForKey:@"path"] stringByAddingPercentEscapesUsingEncoding:
                        NSASCIIStringEncoding];
      
      NSString* fullpath = [NSString stringWithFormat:@"%@/mail/read?%@", SERVER, path];
      NSURL* url = [[NSURL alloc] initWithString: fullpath];
      
      NSMutableURLRequest *URLRequest = [[NSMutableURLRequest alloc] init];
      
      [URLRequest setURL:url];
      [URLRequest setHTTPMethod:@"GET"];
      [URLRequest setTimeoutInterval:20.0];
      
      NSLog(@"URL: %@", url);
      
      // Initiate the URL load.
      [markAsReadConnnections addObject: [[NSURLConnection alloc] initWithRequest:URLRequest delegate:self]];
    }   
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // The table view should not be re-orderable.
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        NSManagedObject *object = [[self fetchedResultsController] objectAtIndexPath:indexPath];
        self.detailViewController.detailItem = object;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        NSManagedObject *object = [[self fetchedResultsController] objectAtIndexPath:indexPath];
        [[segue destinationViewController] setDetailItem:object];
    }
}

#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
  
    NSManagedObjectContext* managedObjectContext = [(AppDelegate*) [[UIApplication sharedApplication] delegate] managedObjectContext];
  
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Message" inManagedObjectContext: managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"time" ascending:NO];
    NSArray *sortDescriptors = @[sortDescriptor];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:managedObjectContext sectionNameKeyPath:nil cacheName:@"Master"];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error]) {
	     // Replace this implementation with code to handle the error appropriately.
	     // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    return _fetchedResultsController;
}    

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

/*
// Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed. 
 
 - (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    // In the simplest, most efficient, case, reload the table view.
    [self.tableView reloadData];
}
 */

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    NSManagedObject *object = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = [[object valueForKey:@"subject"] description];
    cell.detailTextLabel.text = [[object valueForKey:@"time"] description];
}

@end
