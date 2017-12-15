//
//  ViewController.m
//  MYLCustom
//
//  Created by 李明悦 on 2017/12/15.
//  Copyright © 2017年 MyLee. All rights reserved.
//

#import "ViewController.h"
#import "NSURLProtocolCustom.h"

@interface ViewController ()
{
    UIWebView *webView;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:webView];
    
    NSURL *url = [NSURL URLWithString:@"http://www.yuekaihua.com/othersource/urlprotocoldemo.html"];
    [webView loadRequest:[NSURLRequest requestWithURL:url]];
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [NSURLProtocol registerClass:[NSURLProtocolCustom class]];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [NSURLProtocol unregisterClass:[NSURLProtocolCustom class]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
