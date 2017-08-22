//
//  ViewController.m
//  ZYVideoPlayView
//
//  Created by 王智垚 on 2017/8/21.
//  Copyright © 2017年 王智垚. All rights reserved.
//

#import "ViewController.h"
#import "VideoManager.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    UIView *view = [[UIView alloc] initWithFrame:self.view.frame];
    [self.view addSubview:view];
    VideoManager *manager = [VideoManager sharedInstance];
    [manager playWithUrl:[NSURL URLWithString:@"https://flv.bn.netease.com/videolib3/1610/12/vtfiM7162/HD/vtfiM7162-mobile.mp4"] showView:view andSuperView:self.view];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - 关闭设备自动旋转, 然后监测设备旋转方向来旋转avplayerView
- (BOOL)shouldAutorotate {
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}
@end
