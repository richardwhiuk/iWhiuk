//
//  DetailViewController.h
//  iWhiuk
//
//  Created by Richard Whitehouse on 11/12/2012.
//  Copyright (c) 2012 Richard Whitehouse. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DetailViewController : UIViewController <UISplitViewControllerDelegate>

@property (strong, nonatomic) id detailItem;

@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UITextView *headerView;
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *markAsRead;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *format;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *headers;

@end
