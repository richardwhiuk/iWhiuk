//
//  DetailViewController.m
//  iWhiuk
//
//  Created by Richard Whitehouse on 11/12/2012.
//  Copyright (c) 2012 Richard Whitehouse. All rights reserved.
//

#import "Settings.h"
#import "MasterViewController.h"
#import "DetailViewController.h"

enum ViewState {
  TEXT,
  HTML,
  HEADERS,
  DEFAULT
  };

@interface DetailViewController ()
{
  NSURLConnection *dataConnection;
  NSURLConnection *markAsReadConnection;
  NSMutableData *receivedData;
  bool found_text;
  bool found_html;
  enum ViewState mState;
}

@property (strong, nonatomic) UIPopoverController *masterPopoverController;

@end

@implementation DetailViewController

- (id)init
{
  self = [super init];
  dataConnection = nil;
  markAsReadConnection = nil;
  receivedData = nil;
  return self;
}

- (void)viewDidLoad
{
  [self.format setAction:@selector(formatClicked:)];
  [self.headers setAction:@selector(headersClicked:)];
  [self.markAsRead setAction:@selector(markAsReadClicked:)];
}

- (void)markAsReadClicked:(UIBarButtonItem *)button
{
  NSString* path = [[self.detailItem valueForKey:@"path"] stringByAddingPercentEscapesUsingEncoding:
                    NSASCIIStringEncoding];
  
  NSString* fullpath = [NSString stringWithFormat:@"%@/mail/read?%@", SERVER, path];
  NSURL* url = [[NSURL alloc] initWithString: fullpath];
  
  NSMutableURLRequest *URLRequest = [[NSMutableURLRequest alloc] init];
  
  [URLRequest setURL:url];
  [URLRequest setHTTPMethod:@"GET"];
  [URLRequest setTimeoutInterval:20.0];
  
  NSLog(@"URL: %@", url);
  
  // Initiate the URL load.
  markAsReadConnection = [[NSURLConnection alloc] initWithRequest:URLRequest delegate:self];
}

- (void)setState:(enum ViewState) state
{
  if(state == DEFAULT)
  {
    if(found_html)
    {
      state = HTML;
    }
    else
    {
      state = TEXT;
    }
  }
  switch (state)
  {
    case TEXT:
      self.textView.hidden = NO;
      self.webView.hidden = YES;
      self.headerView.hidden = YES;
      if(found_html)
      {
        self.format.enabled = YES;
        self.format.title = @"HTML";
      }
      else
      {
        self.format.enabled = NO;
        self.format.title = @"";
      }
      self.headers.title = @"Headers";
      break;
    case HTML:
      self.webView.hidden = NO;
      self.textView.hidden = YES;
      self.headerView.hidden = YES;
      if(found_text)
      {
        self.format.enabled = YES;
        self.format.title = @"Text";
      }
      else
      {
        self.format.enabled = NO;
        self.format.title = @"";
      }
      self.headers.title = @"Headers";
      break;
    case HEADERS:
      self.headerView.hidden = NO;
      self.textView.hidden = YES;
      self.webView.hidden = YES;
      self.format.enabled = NO;
      self.format.title = @"";
      self.headers.title = @"Body";
      break;
    default:
      abort();
  }
  mState = state;
}

- (void)formatClicked:(UIBarButtonItem *)button
{
  if(mState == HTML)
  {
    [self setState: TEXT];
  }
  else
  {
    [self setState: HTML];
  }
}

- (void)headersClicked:(UIBarButtonItem *)button
{
  if(mState == HEADERS)
  {
    [self setState: DEFAULT];
  }
  else
  {
    [self setState: HEADERS];
  }
}

#pragma mark - Managing the detail item

- (void)setDetailItem:(id)newDetailItem
{
    if (_detailItem != newDetailItem) {
      _detailItem = newDetailItem;
      
      self.webView.hidden = YES;
      self.textView.hidden = YES;
        
      self.title = [self.detailItem valueForKey:@"subject"];
      self.textView.text = @"";
      NSString* path = [[self.detailItem valueForKey:@"path"] stringByAddingPercentEscapesUsingEncoding:
                           NSASCIIStringEncoding];
      
      NSString* fullpath = [NSString stringWithFormat:@"%@/mail/message?%@", SERVER, path];
      NSURL* url = [[NSURL alloc] initWithString: fullpath];
      
      NSMutableURLRequest *URLRequest = [[NSMutableURLRequest alloc] init];
      
      [URLRequest setURL:url];
      [URLRequest setHTTPMethod:@"GET"];
      [URLRequest setTimeoutInterval:20.0];
      
      NSLog(@"URL: %@", url);
      
      // Initiate the URL load.
      NSURLConnection *URLConn = [[NSURLConnection alloc] initWithRequest:URLRequest
                                                                 delegate:self];
      
      receivedData = [[NSMutableData alloc] init];
      
      dataConnection = URLConn;
    }

    if (self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }        
}

- (void)connection:(NSURLConnection *)xiConnection didReceiveData:(NSData *)data
{
  if(dataConnection == xiConnection)
  {
    NSLog(@"Data:");
    [receivedData appendData:data];
  }
}

- (void)connection:(NSURLConnection *)xiConnection didFailWithError:(NSError *)error
{
  if(markAsReadConnection == xiConnection || dataConnection == xiConnection)
  {
    NSLog(@"Erro:");
    NSLog(@"%@", error);
  }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)xiConnection
{
  if(dataConnection == xiConnection)
  {
    NSLog(@"Loaded:");
    NSError* error;
    id data = [NSJSONSerialization JSONObjectWithData:receivedData options:0 error:&error];
    if([data isKindOfClass: [NSDictionary class]])
    {
      NSDictionary* message = (NSDictionary*) data;
      NSArray* body = (NSArray*) [message objectForKey:@"body"];
      for (NSDictionary* part in body)
      {
        NSLog(@"%@", [part objectForKey:@"content-type"]);
        if ((!found_text) && [[part objectForKey:@"content-type"] isEqualToString:@"text/plain"])
        {
          found_text = YES;
          self.textView.text = [part objectForKey:@"body"];
        }
        if ((!found_html) && [[part objectForKey:@"content-type"] isEqualToString:@"text/html"])
        {
          found_html = YES;
          [self.webView loadHTMLString:[part objectForKey:@"body"] baseURL:nil];
        }
      }
      NSMutableString* header_text = [[NSMutableString alloc] init];
      NSDictionary* headers = [message objectForKey:@"headers"];
      for (NSString* header in headers)
      {
        NSArray* values = [headers objectForKey:header];
        for (NSString* value in values)
        {
          [header_text appendString:header];
          [header_text appendString:@": "];
          [header_text appendString:value];
          [header_text appendString:@"\r\n"];
        }
      }
      self.headerView.text = header_text;
    }
    [self setState:DEFAULT];
    if ((!found_html) && (!found_text))
    {
      self.textView.text = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
    }
  }
  else
  {
    [[self navigationController] popViewControllerAnimated:YES];
  }
}

- (void)connection:(NSURLConnection *)xiConnection didReceiveResponse:(NSURLResponse*)response
{
  NSLog(@"HTTP Connection (%@) %u",
        (xiConnection == markAsReadConnection) ? @"mark as read" :
         ((xiConnection == dataConnection) ? @"data" : @"other"),
        [(NSHTTPURLResponse*) response statusCode]);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Split view

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = NSLocalizedString(@"Master", @"Master");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

@end
