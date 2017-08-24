//
//  CMAllMediaAudioManager.m
//  CmosAllMedia
//
//  Created by 王智垚 on 2017/8/22.
//  Copyright © 2017年 liangscofield. All rights reserved.
//

#import "CMAllMediaAudioManager.h"
#import "UIView+Layout.h"

/** 音频来源 **/
typedef NS_ENUM (NSUInteger, AudioFileType) {
    AudioFileType_Network = 0,
    AudioFileType_Local,
};

@interface CMAllMediaAudioManager ()<AVAudioPlayerDelegate> {
    /** 播放途径 YES:扬声器 NO:听筒 **/
    BOOL playWayFlag;
    NSData *audioData;
}
@property (nonatomic, weak) UIView *showView;

@property (nonatomic, copy) NSString *pathName;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;

/** 加载音频时的旋转菊花 **/
@property (nonatomic, strong) UIActivityIndicatorView *actIndicator;
/** 播放喇叭Gif **/
@property (nonatomic, strong) UIImageView *gifImgView;
@end

@implementation CMAllMediaAudioManager
+ (CMAllMediaAudioManager *)sharedInstance {
    static CMAllMediaAudioManager *instance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CMAllMediaAudioManager alloc]init];
    });
    
    return instance;
}

- (id)init {
    if (self = [super init]) {
        playWayFlag = YES;
        [self changeProximityMonitorEnableState:YES];
    }
    return self;
}

- (void)manageAudioWithUrlPath:(NSString *)urlPath audioIsLocalFileType:(BOOL)isLocalFileType audioIsLoudspeaker:(BOOL)isLoudspeaker andShowView:(UIView *)showView {
    if (_actIndicator.isAnimating) return;
    _showView = showView;
    //这里自己写需要保存数据的路径
    NSString *dirPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *cachePath = [NSString stringWithFormat:@"%@/%@", dirPath, [urlPath lastPathComponent]];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath] || isLocalFileType) {
        [self playAudioWithPath:isLocalFileType?urlPath:cachePath whiteType:AudioFileType_Local audioMethod:isLoudspeaker];
    } else {
        [self playAudioWithPath:urlPath whiteType:AudioFileType_Network audioMethod:isLoudspeaker];
    }
}

#pragma mark - private
- (void)playAudioWithPath:(NSString *)path whiteType:(AudioFileType)type audioMethod:(BOOL)isLoudspeaker {
    playWayFlag = isLoudspeaker;
    if (path && path.length > 0) {
        //不随着静音键关闭而静音
        [[AVAudioSession sharedInstance] setCategory:isLoudspeaker?AVAudioSessionCategoryPlayback:AVAudioSessionCategoryPlayAndRecord error:nil];
        //刚刚播放的录音
        if (_pathName && [path isEqualToString:_pathName]) {
            if (_audioPlayer.isPlaying) {
                [self pauseAudio];
            } else {
                [self playAudio];
            }
        } else {
            _pathName = path;
            
            if (_audioPlayer) {
                //停止播放动画
                [_gifImgView stopAnimating];
                [_gifImgView removeFromSuperview];
                [_audioPlayer stop];
                _audioPlayer = nil;
            }
            
            //初始化播放器
            [self.actIndicator removeFromSuperview];
            self.actIndicator.frame = CGRectMake(_showView.width-37, (_showView.height-37)/2, 37, 37);
            [_showView addSubview:_actIndicator];
            [_actIndicator startAnimating];
            self.audioPlayer = [self getAudioPlayer:path witeType:type];
            [self playAudio];
        }
    }
}

- (AVAudioPlayer *)getAudioPlayer:(NSString *)path witeType:(AudioFileType)type {
    NSURL *fileUrl;
    switch (type) {
        case AudioFileType_Network: {
            NSURL *url = [[NSURL alloc]initWithString:path];
            //开辟线程下载数据,该方法不用对线程进行清理
            [NSThread detachNewThreadSelector:@selector(downLoadAudioData:)toTarget:self withObject:url];
            while (audioData==nil) {
                //等待子线程音频数据,不影响主线程
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
            }
            NSString *fileName = [path lastPathComponent];
            
            //将数据保存在本地指定位置Cache中
            NSString *dirPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            NSString *filePath = [NSString stringWithFormat:@"%@/%@", dirPath, fileName];
            [audioData writeToFile:filePath atomically:YES];
            
            fileUrl = [NSURL fileURLWithPath:filePath];
        }
            break;
        case AudioFileType_Local: {
            fileUrl = [NSURL fileURLWithPath:path];
        }
            break;
        default: {
            fileUrl = [NSURL fileURLWithPath:path];
        }
            break;
    }
    
    //初始化播放器并播放
    NSError *error;
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:fileUrl error:&error];
    player.delegate = self;
    [player prepareToPlay];
    if(error){
        NSLog(@"file error %@",error.description);
    }
    return player;
}

//下载网络音频数据
- (void)downLoadAudioData:(NSURL *)audioUrl {
    audioData = [NSData dataWithContentsOfURL:audioUrl];
    if (audioData==nil) {
        [_actIndicator stopAnimating];
        [_actIndicator removeFromSuperview];
        NSLog(@"无效url %@",audioUrl);
    }
}

#pragma mark - AVAudioPlayer播放结束代理方法
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if(flag){
        //停止播放动画
        [_gifImgView stopAnimating];
        [_gifImgView removeFromSuperview];
        //响应播放结束方法
        if (self.audioFinishBlock) {
            self.audioFinishBlock();
        }
    }
}

#pragma mark Action Method
/** 开始播放 **/
- (void)playAudio {
    if (_audioPlayer) {
        [_actIndicator stopAnimating];
        [_actIndicator removeFromSuperview];
        [_gifImgView removeFromSuperview];
        [_showView addSubview:self.gifImgView];
        //开始播放动画
        [_gifImgView startAnimating];
        [_audioPlayer play];
        if (self.audioStartBlock) {
            self.audioStartBlock();
        }
    }
}

/** 暂停播放 **/
- (void)pauseAudio {
    if (_audioPlayer) {
        //停止播放动画
        [_gifImgView stopAnimating];
        [_gifImgView removeFromSuperview];
        [_audioPlayer pause];
        if (self.audioPauseBlock) {
            self.audioPauseBlock();
        }
    }
}

/** 停止播放 **/
- (void)stopAudio {
    self.pathName = @"";
    if (_audioPlayer && _audioPlayer.isPlaying) {
        //停止播放动画
        [_gifImgView stopAnimating];
        [_gifImgView removeFromSuperview];
        [_audioPlayer stop];
        _audioPlayer = nil;
    }
    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO];
    if (self.audioStopBlock) {
        self.audioStopBlock();
    }
}

#pragma mark 懒加载
- (UIActivityIndicatorView *)actIndicator {
    if (!_actIndicator) {
        _actIndicator = [[UIActivityIndicatorView alloc]init];
    }
    return _actIndicator;
}

- (UIImageView *)gifImgView {
    if (!_gifImgView) {
        _gifImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, (_showView.height-30)/2, 30, 30)];
        _gifImgView.image = [UIImage imageNamed:@"icon_audio_play4"];
        //创建一个数组添加要播放的图片
        NSMutableArray *imgArray = [NSMutableArray array];
        for (int i=1; i<5; i++) {
            NSString *imgName = [NSString stringWithFormat:@"icon_audio_play%d", i];
            UIImage *image = kVideoViewPicName(imgName);
            [imgArray addObject:image];
        }
        //存动画图片数组
        _gifImgView.animationImages = imgArray;
        //设置执行一次完整动画的时长
        _gifImgView.animationDuration = 2;
        //动画重复次数 （0为重复播放）
        _gifImgView.animationRepeatCount = 0;
    }
    return _gifImgView;
}

#pragma mark - 近距离传感器
- (void)changeProximityMonitorEnableState:(BOOL)enable {
    [[UIDevice currentDevice] setProximityMonitoringEnabled:YES];
    if ([UIDevice currentDevice].proximityMonitoringEnabled == YES) {
        if (enable) {
            //添加近距离事件监听，添加前先设置为YES，如果设置完后还是NO的读话，说明当前设备没有近距离传感器
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sensorStateChange:) name:UIDeviceProximityStateDidChangeNotification object:nil];
        } else {
            //删除近距离事件监听
            [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceProximityStateDidChangeNotification object:nil];
            [[UIDevice currentDevice] setProximityMonitoringEnabled:NO];
        }
    }
}

/** 传感器状态改变 **/
- (void)sensorStateChange:(NSNotificationCenter *)notification {
    //如果此时手机靠近面部放在耳朵旁，那么声音将通过听筒输出，并将屏幕变暗
    if ([[UIDevice currentDevice] proximityState] == YES) {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    } else {
        [[AVAudioSession sharedInstance] setCategory:playWayFlag? AVAudioSessionCategoryPlayback:AVAudioSessionCategoryPlayAndRecord error:nil];
        if (!_audioPlayer || !_audioPlayer.isPlaying) {
            //没有播放了，也没有在黑屏状态下，就可以把距离传感器关了
            [[UIDevice currentDevice] setProximityMonitoringEnabled:NO];
        }
    }
}

//清除所有缓存
+ (void)clearAllAudioCache {
    NSFileManager *fileManager=[NSFileManager defaultManager];
    //这里自己写需要保存数据的路径
    NSString *cachPath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject;
    NSArray *childFiles = [fileManager subpathsAtPath:cachPath];
    for (NSString *fileName in childFiles) {
        //如有需要，加入条件，过滤掉不想删除的文件
        NSLog(@"%@", fileName);
        if ([fileName.pathExtension isEqualToString:@"mp3"]) {
            NSString *absolutePath=[cachPath stringByAppendingPathComponent:fileName];
            [fileManager removeItemAtPath:absolutePath error:nil];
        }
    }
}

#pragma mark 销毁
- (void)dealloc {
    [self changeProximityMonitorEnableState:NO];
}
@end
