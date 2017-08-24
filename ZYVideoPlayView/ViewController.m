//
//  ViewController.m
//  ZYVideoPlayView
//
//  Created by 王智垚 on 2017/8/21.
//  Copyright © 2017年 王智垚. All rights reserved.
//

#import "ViewController.h"
#import "VideoManager.h"
#import "CMAllMediaAudioManager.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    [self configureVideoPlayView];
//    [self configureAudioPlayerView];
}

//播放视频
- (void)configureVideoPlayView {
    UIView *view = [[UIView alloc] initWithFrame:self.view.frame];
    [self.view addSubview:view];
    VideoManager *manager = [VideoManager sharedInstance];
    [manager playWithUrl:[NSURL URLWithString:@"https://flv.bn.netease.com/videolib3/1610/12/vtfiM7162/HD/vtfiM7162-mobile.mp4"] showView:view andSuperView:self.view];
}

//播放音频
- (void)configureAudioPlayerView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(100, 140, 60, 30)];
    view.backgroundColor = [UIColor cyanColor];
    [self.view addSubview:view];
    CMAllMediaAudioManager *audio = [CMAllMediaAudioManager sharedInstance];
    //1.网络音频
//    [audio manageAudioWithUrlPath:@"http://audio.xmcdn.com/group5/M06/E9/4B/wKgDtlSRSxmyDUkVAB74Cqf1V0Y663.mp3" audioIsLocalFileType:NO audioIsLoudspeaker:YES andShowView:view];
    //2.本地音频
    NSString *bundlePath=[[NSBundle bundleForClass:[self class]] resourcePath];
    NSArray *arrMp3=[NSBundle pathsForResourcesOfType:@"mp3" inDirectory:bundlePath];
    NSString *filePath = arrMp3.firstObject;
    [audio manageAudioWithUrlPath:filePath audioIsLocalFileType:YES audioIsLoudspeaker:YES andShowView:view];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - 关闭设备自动旋转, 然后监测设备旋转方向来旋转avplayerView
- (BOOL)shouldAutorotate {
    return NO;
}
@end

@implementation UINavigationController (Rotation)
- (BOOL)shouldAutorotate {
    return [self.topViewController shouldAutorotate];
}
@end
