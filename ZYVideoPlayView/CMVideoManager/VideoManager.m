//
//  VideoManager.m
//  ZYVideoPlayView
//
//  Created by 王智垚 on 2017/8/21.
//  Copyright © 2017年 王智垚. All rights reserved.
//

#import "VideoManager.h"
#import "VideoPlayerView.h"
#import "FFOrRewindView.h"
#import "MediaLightView.h"
#import "UIView+Layout.h"
#import <MediaPlayer/MediaPlayer.h>

#define kMinMoveDistance 10

NSString *const kPlayerStateChanged        = @"PlayerStateChanged";
NSString *const kPlayerProgressChanged     = @"PlayerProgressChanged";
NSString *const kPlayerLoadProgressChanged = @"PlayerLoadProgressChanged";

static NSString *const VideoPlayerItemStatusKeyPath = @"status";
static NSString *const VideoPlayerItemLoadedTimeRangesKeyPath = @"loadedTimeRanges";
static NSString *const VideoPlayerItemPlaybackBufferEmptyKeyPath = @"playbackBufferEmpty";
static NSString *const VideoPlayerItemPresentationSizeKeyPath = @"presentationSize";

typedef enum : NSUInteger {
    PlayerControlTypeProgress,
    PlayerControlTypeVoice,
    PlayerControlTypeLight,
    PlayerControlTypeNone = 999,
} PlayerControlType;

@interface VideoManager ()<UIGestureRecognizerDelegate> {
    //用来控制上下菜单view隐藏的timer
    NSTimer *hiddenTimer;
    //记录当前界面旋转方向
    UIInterfaceOrientation _currentOrientation;
    //用来判断手势是否移动过
    BOOL _hasMoved;
    //判断是否已经判断出手势划的方向
    BOOL _controlJudge;
    //触摸开始触碰到的点
    CGPoint _touchBeginPoint;
    //记录触摸开始时的视频播放的时间
    float _touchBeginValue;
    //记录触摸开始亮度
    float _touchBeginLightValue;
    //记录触摸开始的音量
    float _touchBeginVoiceValue;
}
@property (nonatomic, assign) PlayerState state;
@property (nonatomic, assign) CGFloat loadedProgress;
@property (nonatomic, assign) CGFloat duration;
@property (nonatomic, assign) CGFloat current;
/** 播放界面的父页面 **/
@property (nonatomic, weak) UIView *superView;
@property (nonatomic, weak) UIView *showView;
@property (nonatomic, strong) VideoPlayerView *playerView;
/** 事件响应View **/
@property (nonatomic, strong) UIView *touchView;
/** 视频展示ViewRect **/
@property (nonatomic, assign) CGRect showViewRect;
/** 视频展示Center **/
@property (nonatomic, assign) CGPoint showViewCenter;

/** 手势判定(进度、声音、亮度) **/
@property (nonatomic, assign) PlayerControlType controlType;
/** 全屏状态栏的背景view **/
@property (nonatomic, strong) UIView *statusBarBgView;
/** 上工具条 **/
@property (nonatomic, strong) UIView  *topToolView;
/** 关闭按钮 **/
@property (nonatomic, strong) UIButton *closeButton;
/** 进入媒体库按钮 **/
@property (nonatomic, strong) UIButton *mediaButton;
/** 下工具条 **/
@property (nonatomic, strong) UIView  *toolView;
/** 开始/正在播放点 **/
@property (nonatomic, strong) UILabel *currentTimeLb;
/** 总播放时间 **/
@property (nonatomic, strong) UILabel *totalTimeLb;
/** 缓冲进度条 **/
@property (nonatomic, strong) UIProgressView *videoProgressView;
/** 进度条滑竿 **/
@property (nonatomic, strong) UISlider *playSlider;
/** 播放暂停按钮 **/
@property (nonatomic, strong) UIButton *stopButton;
/** 恢复播放按钮 **/
@property (nonatomic, strong) UIButton *recoverPlayBtn;
/** 全屏按钮 **/
@property (nonatomic, strong) UIButton *screenButton;
/** 重播按钮 **/
@property (nonatomic, strong) UIButton *repeatBtn;
/** 音量控制控件 **/
@property (nonatomic, strong) MPVolumeView *volumeView;
/** 控制音量 **/
@property (nonatomic, strong) UISlider *volumeSlider;
/** 控制进度 **/
@property (nonatomic, strong) FFOrRewindView *ffOrRewindView;

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVAsset *videoAsset;
@property (nonatomic, strong) AVURLAsset *videoURLAsset;
@property (nonatomic, strong) AVPlayerItem *currentPlayerItem;

/** 加载视频时的旋转菊花 **/
@property (nonatomic, strong) UIActivityIndicatorView *actIndicator;
/** 播放进度监听 **/
@property (nonatomic, strong) NSObject *playbackTimeObserver;

/** 是否被暂停 **/
@property (nonatomic, assign) BOOL isPause;
/** 是否下载完毕 **/
@property (nonatomic, assign) BOOL isFinished;
@property (nonatomic, assign) BOOL isFullScreen;
@property (nonatomic, assign) BOOL canFullScreen;

@end

@implementation VideoManager
static VideoManager *instance;
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc]init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isPause = YES;
        _isFinished = NO;
        _duration = 0;
        _current  = 0;
        _loadedProgress = 0;
        _state = PlayerStateStopped;
        _stopInBackground = NO;
        _isFullScreen = NO;
        _canFullScreen = YES;
        _playRepatCount = 1;
        _playCount = 1;
        
        UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
        switch (orientation) {
            case UIDeviceOrientationPortrait:
                _currentOrientation = UIInterfaceOrientationPortrait;
                break;
            case UIDeviceOrientationLandscapeLeft:
                _currentOrientation = UIInterfaceOrientationLandscapeLeft;
                break;
            case UIDeviceOrientationLandscapeRight:
                _currentOrientation = UIInterfaceOrientationLandscapeRight;
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                _currentOrientation = UIInterfaceOrientationPortraitUpsideDown;
                break;
            default:
                break;
        }
        [MediaLightView sharedInstance];
        [self configureVolume];
    }
    return self;
}

- (void)playWithUrl:(NSURL *)url showView:(UIView *)showView andSuperView:(UIView *)superView {
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    components.scheme = @"streaming";
    NSURL *playUrl = [components URL];
    NSString *videoFile = [NSString stringWithFormat:@"%@.mp4", playUrl.absoluteString];
    
    //这里自己写需要保存数据的路径
    NSString *document = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    NSString *cachePath =  [document stringByAppendingPathComponent:videoFile];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
        NSURL *localURL = [NSURL fileURLWithPath:cachePath];
        [self playWithVideoUrl:localURL showView:showView andSuperView:superView];
    } else {
        [self playWithVideoUrl:url showView:showView andSuperView:superView];
    }
}

- (void)playWithVideoUrl:(NSURL *)url showView:(UIView *)showView andSuperView:(UIView *)superView {
    [self.player pause];
    [self removeAllObserver];
    
    self.isPause = NO;
    self.isFinished = NO;
    self.duration = 0;
    self.current  = 0;
    self.loadedProgress = 0;
    
    _showView = showView;
    _showViewRect = showView.bounds;
    _showViewCenter = showView.center;
    _superView = superView;
    
    NSString *str = [url absoluteString];
    //如果是本地资源，直接播放
    if ([str hasPrefix:@"https"] || [str hasPrefix:@"http"]) {
        self.videoURLAsset = [AVURLAsset URLAssetWithURL:url options:nil];
        self.currentPlayerItem = [AVPlayerItem playerItemWithAsset:_videoURLAsset];
    } else {
        self.videoAsset = [AVURLAsset URLAssetWithURL:url options:nil];
        self.currentPlayerItem = [AVPlayerItem playerItemWithAsset:_videoAsset];
    }
    
    if (!self.player) {
        self.player = [AVPlayer playerWithPlayerItem:self.currentPlayerItem];
    } else {
        [self.player replaceCurrentItemWithPlayerItem:self.currentPlayerItem];
    }
    
    //声音播放
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setActive:YES error:nil];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    //此处为视频填充模式
    [(AVPlayerLayer *)self.playerView.layer setVideoGravity: AVLayerVideoGravityResizeAspect];
    [(AVPlayerLayer *)self.playerView.layer setPlayer:self.player];
    
    //添加监听
    [self addAllObserver];
    
    if ([url.scheme isEqualToString:@"file"]) {
        // 如果已经在PlayerStatePlaying，则直接发通知，否则设置状态
        if (self.state == PlayerStatePlaying) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kPlayerStateChanged object:nil];
        } else {
            self.state = PlayerStatePlaying;
        }
    } else {
        // 如果已经在PlayerStateBuffering，则直接发通知，否则设置状态
        if (self.state == PlayerStateBuffering) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kPlayerStateChanged object:nil];
        } else {
            self.state = PlayerStateBuffering;
        }
    }
    
    //配置UI
    [self configureVideoView];
}

#pragma mark - 设置进度条、暂停等组件
/**  获取系统音量 **/
- (void)configureVolume {
    MPVolumeView *volumeView = [[MPVolumeView alloc] init];
    _volumeSlider = nil;
    for (UIView *view in [volumeView subviews]){
        if ([view.class.description isEqualToString:@"MPVolumeSlider"]){
            self.volumeSlider = (UISlider *)view;
            break;
        }
    }
}

- (void)configureVideoView {
    [self.playerView removeFromSuperview];
    self.playerView.frame = CGRectMake(0, 0, _showView.width, _showView.height);
    [_showView addSubview:self.playerView];
    
    [self.statusBarBgView removeFromSuperview];
    self.statusBarBgView.frame = CGRectMake(0, 0, kScreenWidth, 20);
    [_showView addSubview:self.statusBarBgView];
    
    [self.actIndicator removeFromSuperview];
    self.actIndicator.frame = CGRectMake((_showView.width - 37) / 2, (_showView.height - 37) / 2, 37, 37);
    [_showView addSubview:self.actIndicator];
    
    [self.touchView removeFromSuperview];
    self.touchView.frame = CGRectMake(0, 0, _showView.width, _showView.height - 44);
    [_showView addSubview:self.touchView];
    
    [self.recoverPlayBtn removeFromSuperview];
    self.recoverPlayBtn.frame = CGRectMake(0, 0, 60, 60);
    self.recoverPlayBtn.center = CGPointMake(_showView.width/2, _showView.height/2);
    [_showView addSubview:self.recoverPlayBtn];
    
    [self.topToolView removeAllSubviews];
    self.topToolView.frame = CGRectMake(0, 0, _showView.width, 44);
    [_showView addSubview:self.topToolView];
    
    [self.toolView removeFromSuperview];
    self.toolView.frame = CGRectMake(0, _showView.height - 44, _showView.width, 44);
    [_showView addSubview:self.toolView];
    
    [self.ffOrRewindView removeFromSuperview];
    self.ffOrRewindView.frame = CGRectMake(0, 0, 120, 60);
    _ffOrRewindView.center = CGPointMake(_showView.width/2, _showView.height/2);
    [_showView addSubview:self.ffOrRewindView];
    
    [self.closeButton removeFromSuperview];
    self.closeButton.frame = CGRectMake(0, 0, 44, 44);
    [_topToolView addSubview:self.closeButton];
    
    [self.mediaButton removeFromSuperview];
    self.mediaButton.frame = CGRectMake(self.topToolView.width - 44, 0, 44, 44);
    [_topToolView addSubview:self.mediaButton];
    
    [self.stopButton removeFromSuperview];
    self.stopButton.frame = CGRectMake(0, 0, 44, 44);
    [self.toolView addSubview:self.stopButton];
    
    [self.screenButton removeFromSuperview];
    self.screenButton.frame = CGRectMake(self.toolView.width - 44, 0, 44, 44);
    [self.toolView addSubview:self.screenButton];
    
    [self.currentTimeLb removeFromSuperview];
    self.currentTimeLb.frame = CGRectMake(44, 0, 52, 44);
    [self.toolView addSubview:self.currentTimeLb];
    
    [self.totalTimeLb removeFromSuperview];
    self.totalTimeLb.frame = CGRectMake(self.toolView.width - 52 - 44, 0, 52, 44);
    [self.toolView addSubview:self.totalTimeLb];
    
    [self.playSlider removeFromSuperview];
    CGFloat playSliderWidth = self.toolView.width - self.currentTimeLb.right - self.totalTimeLb.width - self.screenButton.width;
    self.playSlider.frame = CGRectMake(self.currentTimeLb.right, 0, playSliderWidth, 44);
    [self.toolView addSubview:self.playSlider];
    
    [self.videoProgressView removeFromSuperview];
    self.videoProgressView.frame = CGRectMake(self.playSlider.left, self.playSlider.centerY-1, self.playSlider.width, 1);
    [self.toolView addSubview:self.videoProgressView];
    
    [self.repeatBtn removeFromSuperview];
    self.repeatBtn.frame = CGRectMake(0, 0, 40, 60);
    self.repeatBtn.center = CGPointMake(_showViewCenter.x, _showViewCenter.y);
    [_showView addSubview:self.repeatBtn];
    
    UITapGestureRecognizer * tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAction:)];
    tap.numberOfTapsRequired = 1;
    tap.numberOfTouchesRequired = 1;
    tap.delegate = self;
    [self.touchView addGestureRecognizer:tap];
    
    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [panRecognizer setMinimumNumberOfTouches:1];
    [panRecognizer setMaximumNumberOfTouches:1];
    [panRecognizer setDelegate:self];
    [self.touchView addGestureRecognizer:panRecognizer];
    
    UITapGestureRecognizer *sliderTap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(sliderTapAction:)];
    sliderTap.numberOfTapsRequired = 1;
    sliderTap.numberOfTouchesRequired = 1;
    sliderTap.delegate = self;
    [self.playSlider addGestureRecognizer:sliderTap];
}

#pragma mark - observer
- (void)addAllObserver {
    //播放状态
    [self.currentPlayerItem addObserver:self forKeyPath:VideoPlayerItemStatusKeyPath options:NSKeyValueObservingOptionNew context:nil];
    //缓冲进度
    [self.currentPlayerItem addObserver:self forKeyPath:VideoPlayerItemLoadedTimeRangesKeyPath options:NSKeyValueObservingOptionNew context:nil];
    //网络不佳无缓冲播放
    [self.currentPlayerItem addObserver:self forKeyPath:VideoPlayerItemPlaybackBufferEmptyKeyPath options:NSKeyValueObservingOptionNew context:nil];
    //正在播放时间点
    [self.currentPlayerItem addObserver:self forKeyPath:VideoPlayerItemPresentationSizeKeyPath options:NSKeyValueObservingOptionNew context:nil];
    
    //进入后台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
    //后台激活
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterPlayGround) name:UIApplicationDidBecomeActiveNotification object:nil];
    //播放完成
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.currentPlayerItem];
    //耳机插入/拔掉
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioRouteChangeListenerCallback:) name:AVAudioSessionRouteChangeNotification object:nil];
}

- (void)removeAllObserver {
    if (!self.currentPlayerItem) {
        return;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.currentPlayerItem removeObserver:self forKeyPath:VideoPlayerItemStatusKeyPath];
    [self.currentPlayerItem removeObserver:self forKeyPath:VideoPlayerItemLoadedTimeRangesKeyPath];
    [self.currentPlayerItem removeObserver:self forKeyPath:VideoPlayerItemPlaybackBufferEmptyKeyPath];
    [self.currentPlayerItem removeObserver:self forKeyPath:VideoPlayerItemPresentationSizeKeyPath];
    
    [self.player removeTimeObserver:self.playbackTimeObserver];
    self.playbackTimeObserver = nil;
    self.currentPlayerItem = nil;
}

- (void)appDidEnterBackground {
    if (self.stopInBackground) {
        [self pause];
        self.state = PlayerStatePause;
        self.isPause = NO;
    }
}

- (void)appDidEnterPlayGround {
    if (!self.isPause) {
        [self resume];
        self.state = PlayerStatePlaying;
    }
}

- (void)playerItemDidPlayToEnd:(NSNotification *)notification {
    //如果当前播放次数小于重复播放次数，继续重新播放
    if (self.playCount < self.playRepatCount) {
        self.playCount++;
        [self seekToTime:0];
        [self updateCurrentTime:0];
    } else {
        //重新播放
        self.repeatBtn.hidden = NO;
        [self toolViewHidden];
        self.state = PlayerStateFinish;
        [self.stopButton setImage:kVideoViewPicName(@"icon_play") forState:UIControlStateNormal];
        [self.stopButton setImage:kVideoViewPicName(@"icon_play_hl") forState:UIControlStateHighlighted];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    AVPlayerItem *playerItem = (AVPlayerItem *)object;
    
    if ([VideoPlayerItemStatusKeyPath isEqualToString:keyPath]) {
        if ([playerItem status] == AVPlayerStatusReadyToPlay) {
            
            hiddenTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(toolViewHidden) userInfo:nil repeats:NO];
            [self monitoringPlayback:playerItem];// 给播放器添加计时器
            
        } else if ([playerItem status] == AVPlayerStatusFailed || [playerItem status] == AVPlayerStatusUnknown) {
            [self stop];
        }
    } else if ([VideoPlayerItemLoadedTimeRangesKeyPath isEqualToString:keyPath]) {
        //监听播放器的缓冲进度
        [self calculateDownloadProgress:playerItem];
    } else if ([VideoPlayerItemPlaybackBufferEmptyKeyPath isEqualToString:keyPath]) { //监听播放器在缓冲数据的状态
        [self.actIndicator startAnimating];
        self.actIndicator.hidden = NO;
        if (playerItem.isPlaybackBufferEmpty) {
            self.state = PlayerStateBuffering;
            [self bufferingSomeSecond];
        }
    } else if ([VideoPlayerItemPresentationSizeKeyPath isEqualToString:keyPath]) {
        CGSize size = self.currentPlayerItem.presentationSize;
        static float staticHeight = 0;
        staticHeight = size.height/size.width * kScreenWidth;
        
        //用来监测屏幕旋转
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
        
        _canFullScreen = YES;
    }
}

- (void)monitoringPlayback:(AVPlayerItem *)playerItem {
    self.duration = playerItem.duration.value / playerItem.duration.timescale; //视频总时间
    [self.player play];
    [self updateTotolTime:self.duration];
    [self setPlaySliderValue:self.duration];
    
    __weak __typeof(self)weakSelf = self;
    self.playbackTimeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:NULL usingBlock:^(CMTime time) {
        
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        CGFloat current = playerItem.currentTime.value / playerItem.currentTime.timescale;
        [strongSelf updateCurrentTime:current];
        [strongSelf updateVideoSlider:current];
        if (strongSelf.isPause == NO) {
            strongSelf.state = PlayerStatePlaying;
        }
        
        // 不相等的时候才更新，并发通知，否则seek时会继续跳动
        if (strongSelf.current != current) {
            strongSelf.current = current;
            if (strongSelf.current > strongSelf.duration) {
                strongSelf.duration = strongSelf.current;
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:kPlayerProgressChanged object:nil];
        }
    }];
}

- (void)unmonitoringPlayback:(AVPlayerItem *)playerItem {
    if (self.playbackTimeObserver != nil) {
        [self.player removeTimeObserver:self.playbackTimeObserver];
        self.playbackTimeObserver = nil;
    }
}

- (void)calculateDownloadProgress:(AVPlayerItem *)playerItem {
    NSArray *loadedTimeRanges = [playerItem loadedTimeRanges];
    // 获取缓冲区域
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];
    float startSeconds = CMTimeGetSeconds(timeRange.start);
    float durationSeconds = CMTimeGetSeconds(timeRange.duration);
    //计算缓冲总进度
    NSTimeInterval timeInterval = startSeconds + durationSeconds;
    CMTime duration = playerItem.duration;
    CGFloat totalDuration = CMTimeGetSeconds(duration);
    self.loadedProgress = timeInterval / totalDuration;
    [self.videoProgressView setProgress:timeInterval / totalDuration animated:YES];
}

- (void)bufferingSomeSecond {
    // playbackBufferEmpty会反复进入，因此在bufferingOneSecond延时播放执行完之前再调用bufferingSomeSecond
    static BOOL isBuffering = NO;
    if (isBuffering) {
        return;
    }
    isBuffering = YES;
    
    // 需要先暂停一小会之后再播放，否则网络状况不好的时候时间在走，声音播放不出来
    [self.player pause];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // 如果此时用户已经暂停了，则不再需要开启播放了
        if (self.isPause) {
            isBuffering = NO;
            return;
        }
        
        [self.player play];
        // 如果执行了play还是没有播放则说明还没有缓存好，就再次缓存一段时间
        isBuffering = NO;
        if (!self.currentPlayerItem.isPlaybackLikelyToKeepUp) {
            [self bufferingSomeSecond];
        }
    });
}

/** 耳机插入、拔出事件 **/
- (void)audioRouteChangeListenerCallback:(NSNotification *)notification {
    NSDictionary *interuptionDict = notification.userInfo;
    NSInteger routeChangeReason = [[interuptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    switch (routeChangeReason) {
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            //耳机插入
            break;
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            // 耳机拔掉继续播放
            [self.player play];
            break;
        case AVAudioSessionRouteChangeReasonCategoryChange:
            // called at start - also when other audio wants to play
            NSLog(@"AVAudioSessionRouteChangeReasonCategoryChange");
            break;
    }
}

#pragma mark - 通知中心检测到屏幕旋转
- (void)orientationChanged:(NSNotification *)notification {
    [self updateOrientation];
}

- (void)updateOrientation {
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    switch (orientation) {
        case UIDeviceOrientationPortrait:
            [self toOrientation:UIInterfaceOrientationPortrait];
            break;
        case UIDeviceOrientationLandscapeLeft:
            [self toOrientation:UIInterfaceOrientationLandscapeRight];
            break;
        case UIDeviceOrientationLandscapeRight:
            [self toOrientation:UIInterfaceOrientationLandscapeLeft];
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            [self toOrientation:UIInterfaceOrientationPortraitUpsideDown];
            break;
        default:
            break;
    }
}

#pragma mark - 全屏旋转处理
- (void)fullScreenClicked {
    //如果全屏下
    if (_isFullScreen) {
        [self toOrientation:UIInterfaceOrientationPortrait];
    } else {
        [self toOrientation:UIInterfaceOrientationLandscapeRight];
    }
    [self showToolView];
}

- (void)toOrientation:(UIInterfaceOrientation)orientation {
    if (!_canFullScreen) {
        return;
    }
    
    if (_currentOrientation == orientation) {
        return;
    }
    
    if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown) {
        [self.showView removeFromSuperview];
        [self.superView addSubview:self.showView];
        
        MediaLightView *lightView = [MediaLightView sharedInstance];
        [[UIApplication sharedApplication].keyWindow bringSubviewToFront:lightView];
        
        self.showView.bounds = _showViewRect;
        self.showView.center = _showViewCenter;
        
        self.playerView.top = 0;
        self.playerView.left = 0;
        self.playerView.width = _showViewRect.size.width;
        self.playerView.height = _showViewRect.size.height;
        
        self.touchView.top = 0;
        self.touchView.left = 0;
        self.touchView.width = _showViewRect.size.width;
        self.touchView.height = _showViewRect.size.height-44;
        
        self.topToolView.top = 0;
        self.topToolView.left = 0;
        self.topToolView.width = _showViewRect.size.width;
        
        self.toolView.left = 0;
        self.toolView.bottom = _showViewRect.size.height;
        self.toolView.width = _showViewRect.size.width;
        
        self.recoverPlayBtn.centerX = _showViewRect.size.width/2;
        self.recoverPlayBtn.centerY = _showViewRect.size.height/2;
        
        self.ffOrRewindView.centerX = _showViewRect.size.width/2;
        self.ffOrRewindView.centerY = _showViewRect.size.height/2;
        
        self.mediaButton.left = self.topToolView.width - 44;
        
        self.currentTimeLb.left = 44;
        
        self.totalTimeLb.left = self.toolView.width - 52 - 44;
        
        self.playSlider.width = self.toolView.width - self.currentTimeLb.right - self.totalTimeLb.width - self.screenButton.width;
        
        self.videoProgressView.width = self.playSlider.width;
        
        self.screenButton.left = self.toolView.width-44;
        
        self.repeatBtn.centerX = _showViewRect.size.width/2;
        self.repeatBtn.centerY = _showViewRect.size.height/2;
        
    } else if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight) {
        [self.showView removeFromSuperview];
        [[UIApplication sharedApplication].keyWindow addSubview:self.showView];
        
        // 亮度view加到window最上层
        MediaLightView *lightView = [MediaLightView sharedInstance];
        [[UIApplication sharedApplication].keyWindow insertSubview:self.showView belowSubview:lightView];
        
        self.showView.frame = CGRectMake(0, 0, kScreenHeight, kScreenWidth);
        self.showView.center = [UIApplication sharedApplication].keyWindow.center;
        
        self.playerView.frame = CGRectMake(0, 0, kScreenHeight, kScreenWidth);
        
        self.touchView.frame = CGRectMake(0, 0, _showView.width, _showView.height - 44);
        
        self.topToolView.frame = CGRectMake(0, 0, _showView.width, 44);
        
        self.toolView.frame = CGRectMake(0, _showView.height-44, _showView.width, 44);
        
        self.recoverPlayBtn.center = CGPointMake(_showView.width/2, _showView.height/2);
        
        self.ffOrRewindView.center = CGPointMake(_showView.width/2, _showView.height/2);
        
        self.mediaButton.frame = CGRectMake(self.topToolView.width - 44, 0, 44, 44);
        
        self.currentTimeLb.frame = CGRectMake(44, 0, 52, 44);
        
        self.totalTimeLb.frame = CGRectMake(self.toolView.width - 52 - 44, 0, 52, 44);
        
        CGFloat playSliderWidth = self.toolView.width - self.currentTimeLb.right - self.totalTimeLb.width - self.screenButton.width;
        self.playSlider.frame = CGRectMake(self.currentTimeLb.right, 0, playSliderWidth, 44);
        
        self.videoProgressView.frame = CGRectMake(self.playSlider.left, self.playSlider.centerY-1, self.playSlider.width, 1);
        
        self.screenButton.frame = CGRectMake(self.toolView.width - 44, 0, 44, 44);
        
        self.repeatBtn.center = CGPointMake(_showView.width/2, _showView.height/2);
    }
    
    _currentOrientation = orientation;
    
    
    [UIView animateWithDuration:0.5 animations:^{
        [[UIApplication sharedApplication] setStatusBarOrientation:_currentOrientation animated:YES];
        //旋转视频播放的view和显示亮度的view
        self.showView.transform = [self getOrientation:orientation];
        [MediaLightView sharedInstance].transform = [self getOrientation:orientation];
    }];
}

//根据状态条旋转的方向来旋转 avplayerView
- (CGAffineTransform)getOrientation:(UIInterfaceOrientation)orientation {
    if (orientation == UIInterfaceOrientationPortrait) {
        [self toPortraitUpdate];
        return CGAffineTransformIdentity;
    } else if (orientation == UIInterfaceOrientationLandscapeLeft){
        [self toLandscapeUpdate];
        return CGAffineTransformMakeRotation(-M_PI_2);
    } else if (orientation == UIInterfaceOrientationLandscapeRight){
        [self toLandscapeUpdate];
        return CGAffineTransformMakeRotation(M_PI_2);
    } else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
        [self toPortraitUpdate];
        return CGAffineTransformMakeRotation(M_PI);
    }
    return CGAffineTransformIdentity;
}

-(void)toPortraitUpdate{
    _isFullScreen = NO;
    self.topToolView.hidden = YES;
    self.toolView.hidden = YES;
    //处理状态条
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
    if ([UIApplication sharedApplication].statusBarHidden) {
        [[UIApplication sharedApplication] setStatusBarHidden:NO];
    }
}

- (void)toLandscapeUpdate{
    _isFullScreen = YES;
    
    //处理状态条
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    if (self.toolView.hidden) {
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
    }else{
        [[UIApplication sharedApplication] setStatusBarHidden:NO];
    }
}

#pragma mark setter
//缓存进度更新
- (void)setLoadedProgress:(CGFloat)loadedProgress {
    if (_loadedProgress == loadedProgress) {
        return;
    }
    _loadedProgress = loadedProgress;
    [[NSNotificationCenter defaultCenter] postNotificationName:kPlayerLoadProgressChanged object:nil];
}

//更新播放状态state
- (void)setState:(PlayerState)state {
    if (state != PlayerStateBuffering) {
        [self.actIndicator stopAnimating];
        self.actIndicator.hidden = YES;
    }
    if (_state == state) {
        return;
    }
    
    _state = state;
    if (self.state == PlayerStatePlaying) {
        [self.stopButton setImage:kVideoViewPicName(@"icon_pause") forState:UIControlStateNormal];
        [self.stopButton setImage:kVideoViewPicName(@"icon_pause_hl") forState:UIControlStateHighlighted];
        self.recoverPlayBtn.hidden = YES;
    } else if (self.state == PlayerStatePause) {
        [self.stopButton setImage:kVideoViewPicName(@"icon_play") forState:UIControlStateNormal];
        [self.stopButton setImage:kVideoViewPicName(@"icon_play_hl") forState:UIControlStateHighlighted];
        self.recoverPlayBtn.hidden = NO;
    } else if (self.state == PlayerStateFinish) {
        [self.stopButton setImage:kVideoViewPicName(@"icon_play") forState:UIControlStateNormal];
        [self.stopButton setImage:kVideoViewPicName(@"icon_play_hl") forState:UIControlStateHighlighted];
        self.recoverPlayBtn.hidden = YES;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kPlayerStateChanged object:nil];
}

#pragma mark - UIGestureRecognizerDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch{
    if (_controlJudge) {
        return NO;
    } else {
        return YES;
    }
}

- (void)tapAction:(UITapGestureRecognizer *)tap{
    if (self.toolView.hidden) {
        [self showToolView];
    } else {
        [self toolViewHidden];
    }
}

- (void)sliderTapAction:(UITapGestureRecognizer *)tap {
    if (tap.numberOfTapsRequired == 1) {
        CGPoint touchPoint = [tap locationInView:self.playSlider];
        //NSLog(@"(%f,%f)", touchPoint.x, touchPoint.y);
        //NSLog(@"%f duration:%f", self.playSlider.frame.size.width, self.duration);
        
        float value = (touchPoint.x / self.playSlider.frame.size.width) * self.playSlider.maximumValue;
        
        [self seekToTime:value];
        [self updateCurrentTime:value];
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)recognizer {
    CGPoint touchPoint = [recognizer locationInView:self.touchView];
    //NSLog(@"(%f,%f)", touchPoint.x, touchPoint.y);
    
    if ([(UIPanGestureRecognizer *)recognizer state] == UIGestureRecognizerStateBegan) {
        //触摸开始, 初始化一些值
        _hasMoved = NO;
        _controlJudge = NO;
        _touchBeginValue = self.playSlider.value;
        _touchBeginVoiceValue = _volumeSlider.value;
        _touchBeginLightValue = [UIScreen mainScreen].brightness;
        _touchBeginPoint = touchPoint;
    }
    
    if ([(UIPanGestureRecognizer *)recognizer state] == UIGestureRecognizerStateChanged) {
        
        //如果移动的距离过于小, 就判断为没有移动
        if (fabs(touchPoint.x - _touchBeginPoint.x) < kMinMoveDistance && fabs(touchPoint.y - _touchBeginPoint.y) < kMinMoveDistance) {
            return;
        }
        
        _hasMoved = YES;
        
        //如果还没有判断出是什么手势就进行判断
        if (!_controlJudge) {
            //根据滑动角度的tan值来进行判断
            float tan = fabs(touchPoint.y - _touchBeginPoint.y) / fabs(touchPoint.x - _touchBeginPoint.x);
            
            //当滑动角度小于30度的时候, 进度手势
            if (tan < 1 / sqrt(3)) {
                self.repeatBtn.hidden = YES;
                self.recoverPlayBtn.hidden = YES;
                self.controlType = PlayerControlTypeProgress;
                _controlJudge = YES;
            }
            
            //当滑动角度大于60度的时候, 声音和亮度
            else if (tan > sqrt(3)) {
                //判断是在屏幕的左半边还是右半边滑动, 左侧控制为亮度, 右侧控制音量
                if (_touchBeginPoint.x < self.touchView.frame.size.width / 2) {
                    _controlType = PlayerControlTypeLight;
                }else{
                    _controlType = PlayerControlTypeVoice;
                }
                _controlJudge = YES;
            } else {
                _controlType = PlayerControlTypeNone;
                return;
            }
        }
        
        if (PlayerControlTypeProgress == _controlType) {
            float value = [self moveProgressControllWithTempPoint:touchPoint];
            [self timeValueChangingWithValue:value];
        } else if (PlayerControlTypeVoice == _controlType) {
            //根据触摸开始时的音量和触摸开始时的点去计算出现在滑动到的音量
            float voiceValue = _touchBeginVoiceValue - ((touchPoint.y - _touchBeginPoint.y) / CGRectGetHeight(self.touchView.frame));
            //判断控制一下, 不能超出 0~1
            if (voiceValue <= 0) {
                self.volumeSlider.value = 0;
            } else if (voiceValue >= 1) {
                self.volumeSlider.value = 1;
            } else {
                self.volumeSlider.value = voiceValue;
            }
        } else if (PlayerControlTypeLight == _controlType) {
            [UIScreen mainScreen].brightness -= ((touchPoint.y - _touchBeginPoint.y) / 10000);
        } else if (PlayerControlTypeNone == _controlType) {
            if (self.toolView.hidden) {
                [self showToolView];
            } else {
                [self toolViewHidden];
            }
        }
        
    }
    
    if (([(UIPanGestureRecognizer *)recognizer state] == UIGestureRecognizerStateEnded) || ([(UIPanGestureRecognizer *)recognizer state] == UIGestureRecognizerStateCancelled)) {
        _controlJudge = NO;
        //判断是否移动过,
        if (_hasMoved) {
            if (PlayerControlTypeProgress == _controlType) {
                float value = [self moveProgressControllWithTempPoint:touchPoint];
                [self seekToTime:value];
                self.ffOrRewindView.hidden = YES;
            }
        }
    }
}

#pragma mark - 用来控制移动过程中计算手指划过的时间
- (float)moveProgressControllWithTempPoint:(CGPoint)tempPoint{
    float tempValue = _touchBeginValue + 90 * ((tempPoint.x - _touchBeginPoint.x) / kScreenWidth);
    if (tempValue > self.duration) {
        tempValue = self.duration;
    } else if (tempValue < 0){
        tempValue = 0.0f;
    }
    return tempValue;
}

#pragma mark - 用来显示时间的view在时间发生变化时所作的操作
- (void)timeValueChangingWithValue:(float)value {
    if (value > _touchBeginValue) {
        _ffOrRewindView.stateImageView.image = kVideoViewPicName(@"icon_progress_r");
    } else if (value < _touchBeginValue) {
        _ffOrRewindView.stateImageView.image = kVideoViewPicName(@"icon_progress_l");
    }
    _ffOrRewindView.hidden = NO;
    NSString * tempTime = [self convertTime:value];
    if (tempTime.length > 5) {
        _ffOrRewindView.timeLabel.text = [NSString stringWithFormat:@"00:%@/%@", tempTime, self.totalTimeLb.text];
    } else {
        _ffOrRewindView.timeLabel.text = [NSString stringWithFormat:@"%@/%@", tempTime, self.totalTimeLb.text];
    }
}

#pragma mark - 控制条隐藏
- (void)toolViewHidden {
    self.topToolView.hidden = YES;
    self.toolView.hidden = YES;
    self.statusBarBgView.hidden = YES;
    
    if (_isFullScreen) {
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
    }
    [hiddenTimer invalidate];
}

#pragma mark - 控制条退出隐藏
- (void)showToolView {
    if (!self.repeatBtn.hidden) {
        return;
    }
    self.topToolView.hidden = NO;
    self.toolView.hidden = NO;
    
    if (_isFullScreen) {
        self.statusBarBgView.hidden = NO;
    } else {
        self.statusBarBgView.hidden = YES;
    }
    
    if ([UIApplication sharedApplication].statusBarHidden) {
        [[UIApplication sharedApplication] setStatusBarHidden:NO];
    }
    if (!hiddenTimer.valid) {
        hiddenTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(toolViewHidden) userInfo:nil repeats:NO];
    } else {
        [hiddenTimer invalidate];
        hiddenTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(toolViewHidden) userInfo:nil repeats:NO];
    }
}

#pragma mark - 事件响应
//手指结束拖动，播放器从当前点开始播放，开启滑竿的时间走动
- (void)playSliderChangeEnd:(UISlider *)slider {
    [self seekToTime:slider.value];
    [self updateCurrentTime:slider.value];
    [self.stopButton setImage:kVideoViewPicName(@"icon_pause") forState:UIControlStateNormal];
    [self.stopButton setImage:kVideoViewPicName(@"icon_pause_hl") forState:UIControlStateHighlighted];
}

//手指正在拖动，播放器继续播放，但是停止滑竿的时间走动
- (void)playSliderChange:(UISlider *)slider {
    [self updateCurrentTime:slider.value];
}

//进度条拖动
- (void)setPlaySliderValue:(CGFloat)time {
    self.playSlider.minimumValue = 0.0;
    self.playSlider.maximumValue = (NSInteger)time;
}

#pragma mark - private
/** 指定某时刻播放 **/
- (void)seekToTime:(CGFloat)seconds {
    if (self.state == PlayerStateStopped) {
        return;
    }
    
    seconds = MAX(0, seconds);
    seconds = MIN(seconds, self.duration);
    
    [self.player pause];
    [self.player seekToTime:CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC) completionHandler:^(BOOL finished) {
        self.isPause = NO;
        [self.player play];
        if (!self.currentPlayerItem.isPlaybackLikelyToKeepUp) {
            self.state = PlayerStateBuffering;
            
            self.actIndicator.hidden = NO;
            [self.actIndicator startAnimating];
        }
        
    }];
}

/**  计算播放进度 **/
- (CGFloat)progress {
    if (self.duration > 0) {
        return self.current / self.duration;
    }
    return 0;
}

/**  更新当前播放时间点 **/
- (void)updateCurrentTime:(CGFloat)time {
    long videocurrent = ceil(time);
    
    NSString *str = nil;
    if (videocurrent < 3600) {
        str =  [NSString stringWithFormat:@"%02li:%02li",lround(floor(videocurrent/60.f)),lround(floor(videocurrent/1.f))%60];
    } else {
        str =  [NSString stringWithFormat:@"%02li:%02li:%02li",lround(floor(videocurrent/3600.f)),lround(floor(videocurrent%3600)/60.f),lround(floor(videocurrent/1.f))%60];
    }
    
    self.currentTimeLb.text = str;
}

/**
 *  更新所有时间
 *
 *  @param time 时间（秒）
 */
- (void)updateTotolTime:(CGFloat)time {
    long videoLenth = ceil(time);
    NSString *strtotol = nil;
    if (videoLenth < 3600) {
        strtotol =  [NSString stringWithFormat:@"%02li:%02li",lround(floor(videoLenth/60.f)),lround(floor(videoLenth/1.f))%60];
    } else {
        strtotol =  [NSString stringWithFormat:@"%02li:%02li:%02li",lround(floor(videoLenth/3600.f)),lround(floor(videoLenth%3600)/60.f),lround(floor(videoLenth/1.f))%60];
    }
    
    self.totalTimeLb.text = strtotol;
}

/**  更新Slider **/
- (void)updateVideoSlider:(CGFloat)currentSecond {
    [self.playSlider setValue:currentSecond animated:YES];
}

/**  暂停或者播放 **/
- (void)resumeOrPauseClicked {
    if (!self.currentPlayerItem) {
        return;
    }
    self.repeatBtn.hidden = YES;
    if (self.state == PlayerStatePlaying) {
        [self.stopButton setImage:kVideoViewPicName(@"icon_play") forState:UIControlStateNormal];
        [self.stopButton setImage:kVideoViewPicName(@"icon_play_hl") forState:UIControlStateHighlighted];
        [self.player pause];
        self.state = PlayerStatePause;
    } else if (self.state == PlayerStatePause) {
        [self.stopButton setImage:kVideoViewPicName(@"icon_pause") forState:UIControlStateNormal];
        [self.stopButton setImage:kVideoViewPicName(@"icon_pause_hl") forState:UIControlStateHighlighted];
        [self.player play];
        self.state = PlayerStatePlaying;
    } else if (self.state == PlayerStateFinish) {
        [self.stopButton setImage:kVideoViewPicName(@"icon_pause") forState:UIControlStateNormal];
        [self.stopButton setImage:kVideoViewPicName(@"icon_pause_hl") forState:UIControlStateHighlighted];
        [self seekToTime:0.0];
        self.state = PlayerStatePlaying;
    }
    self.isPause = YES;
}

/**  重播 **/
- (void)repeatPlayClicked {
    [self showToolView];
    [self resumeOrPauseClicked];
}

/**  重新播放 **/
- (void)resume {
    if (!self.currentPlayerItem) {
        return;
    }
    
    [self.stopButton setImage:kVideoViewPicName(@"icon_pause") forState:UIControlStateNormal];
    [self.stopButton setImage:kVideoViewPicName(@"icon_pause_hl") forState:UIControlStateHighlighted];
    self.isPause = NO;
    self.recoverPlayBtn.hidden = YES;
    [self.player play];
}

/**  暂停播放 **/
- (void)pause {
    if (!self.currentPlayerItem) {
        return;
    }
    
    [self.stopButton setImage:kVideoViewPicName(@"icon_play") forState:UIControlStateNormal];
    [self.stopButton setImage:kVideoViewPicName(@"icon_play_hl") forState:UIControlStateHighlighted];
    self.isPause = YES;
    self.state = PlayerStatePause;
    [self.player pause];
}

/**  停止播放 **/
- (void)stop {
    self.isPause = YES;
    self.duration = 0;
    self.current  = 0;
    self.loadedProgress = 0;
    self.state = PlayerStateStopped;
    [self.player pause];
    [self removeAllObserver];
    self.repeatBtn.hidden = YES;
    [self toolViewHidden];
    [[NSNotificationCenter defaultCenter] postNotificationName:kPlayerProgressChanged object:nil];
}

/** 恢复播放 **/
- (void)recoverPlayClicked:(UIButton *)sender {
    [self resume];
}

/** 关闭播放器 **/
- (void)closeVideoClicked {
    //    if (self.closeBtnBlock) {
    //        self.closeBtnBlock();
    //    }
    //    [self stop];
    //    [_showView removeFromSuperview];
    //    instance = nil;
}

/** 进入媒体库 **/
- (void)enterMediaClicked {
    if (self.enterMediaBlock) {
        self.enterMediaBlock();
    }
}

//清除所有缓存
+ (void)clearAllVideoCache {
    NSFileManager *fileManager=[NSFileManager defaultManager];
    //这里自己写需要保存数据的路径
    NSString *cachPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    NSArray *childFiles = [fileManager subpathsAtPath:cachPath];
    for (NSString *fileName in childFiles) {
        //如有需要，加入条件，过滤掉不想删除的文件
        NSLog(@"%@", fileName);
        if ([fileName.pathExtension isEqualToString:@"mp4"]) {
            NSString *absolutePath=[cachPath stringByAppendingPathComponent:fileName];
            [fileManager removeItemAtPath:absolutePath error:nil];
        }
    }
}

//所有缓存的文件大小
+ (double)allVideoCacheSize {
    double cacheVideoSize = 0.0f;
    NSFileManager *fileManager=[NSFileManager defaultManager];
    //这里自己写需要保存数据的路径
    NSString *cachPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    NSArray *childFiles = [fileManager subpathsAtPath:cachPath];
    for (NSString *fileName in childFiles) {
        //如有需要，加入条件，过滤掉不想删除的文件
        NSLog(@"%@", fileName);
        if ([fileName.pathExtension isEqualToString:@"mp4"]) {
            NSString *path = [cachPath stringByAppendingPathComponent: fileName];
            NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath: path error: nil ];
            cacheVideoSize += ((double)([fileAttributes fileSize ]) / 1024.0 / 1024.0);
        }
    }
    return cacheVideoSize;
}

//时间换算
- (NSString *)convertTime:(long long)timeSecond {
    NSString * theLastTime = nil;
    if (timeSecond < 60) {
        theLastTime = [NSString stringWithFormat:@"00:%.2lld", timeSecond];
    } else if (timeSecond >= 60 && timeSecond < 3600){
        theLastTime = [NSString stringWithFormat:@"%.2lld:%.2lld", timeSecond/60, timeSecond%60];
    } else if (timeSecond >= 3600){
        theLastTime = [NSString stringWithFormat:@"%.2lld:%.2lld:%.2lld", timeSecond/3600, timeSecond%3600/60, timeSecond%60];
    }
    return theLastTime;
}

#pragma mark - 界面控件初始化
- (VideoPlayerView *)playerView {
    if (!_playerView) {
        _playerView = [[VideoPlayerView alloc] init];
    }
    return _playerView;
}

- (UIView *)statusBarBgView {
    if (!_statusBarBgView) {
        _statusBarBgView = [[UIView alloc] init];
        _statusBarBgView.backgroundColor = [UIColor blackColor];
        _statusBarBgView.hidden = YES;
    }
    return _statusBarBgView;
}

- (UIView *)topToolView {
    if (!_topToolView) {
        _topToolView = [[UIView alloc] init];
        _topToolView.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5];
    }
    return _topToolView;
}

- (UIView *)toolView {
    if (!_toolView) {
        _toolView = [[UIView alloc] init];
        _toolView.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5];
    }
    return _toolView;
}

- (UIView *)touchView {
    if (!_touchView) {
        _touchView = [[UIView alloc] init];
        _touchView.backgroundColor = [UIColor clearColor];
    }
    return _touchView;
}

- (UILabel *)currentTimeLb {
    if (!_currentTimeLb) {
        _currentTimeLb = [[UILabel alloc]init];
        _currentTimeLb.text = @"00:00";
        _currentTimeLb.textColor = [UIColor whiteColor];
        _currentTimeLb.font = [UIFont systemFontOfSize:10.0];
        _currentTimeLb.textAlignment = NSTextAlignmentCenter;
    }
    return _currentTimeLb;
}

- (UILabel *)totalTimeLb {
    if (!_totalTimeLb) {
        _totalTimeLb = [[UILabel alloc]init];
        _totalTimeLb.text = @"--:--";
        _totalTimeLb.textColor = [UIColor whiteColor];
        _totalTimeLb.font = [UIFont systemFontOfSize:10.0];
        _totalTimeLb.textAlignment = NSTextAlignmentCenter;
    }
    return _totalTimeLb;
}

- (UIProgressView *)videoProgressView {
    if (!_videoProgressView) {
        _videoProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        _videoProgressView.progressTintColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.5];  //填充部分颜色
        _videoProgressView.trackTintColor = [UIColor clearColor];   // 未填充部分颜色
        _videoProgressView.layer.cornerRadius = 0.5;
        _videoProgressView.layer.masksToBounds = YES;
        CGAffineTransform transform = CGAffineTransformMakeScale(1.0, 1.0);
        _videoProgressView.transform = transform;
    }
    return _videoProgressView;
}

- (UISlider *)playSlider {
    if (!_playSlider) {
        _playSlider = [[UISlider alloc] init];
        [_playSlider setThumbImage:kVideoViewPicName(@"icon_progress") forState:UIControlStateNormal];
        _playSlider.minimumTrackTintColor = [UIColor whiteColor];
        _playSlider.maximumTrackTintColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.5];
        [_playSlider addTarget:self action:@selector(playSliderChange:) forControlEvents:UIControlEventValueChanged];//拖动滑竿更新时间
        [_playSlider addTarget:self action:@selector(playSliderChangeEnd:) forControlEvents:UIControlEventTouchUpInside];//松手滑块拖动停止
        [_playSlider addTarget:self action:@selector(playSliderChangeEnd:) forControlEvents:UIControlEventTouchUpOutside];
        [_playSlider addTarget:self action:@selector(playSliderChangeEnd:) forControlEvents:UIControlEventTouchCancel];
    }
    
    return _playSlider;
}

- (UIButton *)closeButton {
    if (!_closeButton) {
        _closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_closeButton addTarget:self action:@selector(closeVideoClicked) forControlEvents:UIControlEventTouchUpInside];
        [_closeButton setImage:kVideoViewPicName(@"icon_close_normal") forState:UIControlStateNormal];
        [_closeButton setImage:kVideoViewPicName(@"icon_close_pressed") forState:UIControlStateHighlighted];
    }
    return _closeButton;
}

- (UIButton *)mediaButton {
    if (!_mediaButton) {
        _mediaButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_mediaButton addTarget:self action:@selector(enterMediaClicked) forControlEvents:UIControlEventTouchUpInside];
        [_mediaButton setImage:kVideoViewPicName(@"icon_close_normal") forState:UIControlStateNormal];
        [_mediaButton setImage:kVideoViewPicName(@"icon_close_pressed") forState:UIControlStateHighlighted];
    }
    return _mediaButton;
}

- (UIButton *)stopButton {
    if (!_stopButton) {
        _stopButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_stopButton addTarget:self action:@selector(resumeOrPauseClicked) forControlEvents:UIControlEventTouchUpInside];
        [_stopButton setImage:kVideoViewPicName(@"icon_pause") forState:UIControlStateNormal];
        [_stopButton setImage:kVideoViewPicName(@"icon_pause_hl") forState:UIControlStateHighlighted];
    }
    return _stopButton;
}

- (UIButton *)recoverPlayBtn {
    if (!_recoverPlayBtn) {
        _recoverPlayBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _recoverPlayBtn.hidden = YES;
        [_recoverPlayBtn addTarget:self action:@selector(recoverPlayClicked:) forControlEvents:UIControlEventTouchUpInside];
        [_recoverPlayBtn setImage:kVideoViewPicName(@"icon_center_play") forState:UIControlStateNormal];
    }
    return _recoverPlayBtn;
}

- (UIButton *)screenButton {
    if (!_screenButton) {
        _screenButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_screenButton addTarget:self action:@selector(fullScreenClicked) forControlEvents:UIControlEventTouchUpInside];
        [_screenButton setImage:kVideoViewPicName(@"icon_full") forState:UIControlStateNormal];
        [_screenButton setImage:kVideoViewPicName(@"icon_full") forState:UIControlStateHighlighted];
    }
    return _screenButton;
}

- (UIButton *)repeatBtn {
    if (!_repeatBtn) {
        _repeatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_repeatBtn setImage:kVideoViewPicName(@"icon_repeat_video") forState:UIControlStateNormal];
        [_repeatBtn addTarget:self action:@selector(repeatPlayClicked) forControlEvents:UIControlEventTouchUpInside];
        _repeatBtn.hidden = YES;
    }
    return _repeatBtn;
}

- (UIActivityIndicatorView *)actIndicator {
    if (!_actIndicator) {
        _actIndicator = [[UIActivityIndicatorView alloc]init];
    }
    return _actIndicator;
}

- (FFOrRewindView *)ffOrRewindView {
    if (!_ffOrRewindView) {
        _ffOrRewindView = [[FFOrRewindView alloc]initWithFrame:CGRectMake(0, 0, 120, 60)];
        _ffOrRewindView.hidden = YES;
        _ffOrRewindView.layer.cornerRadius = 10.0;
    }
    return _ffOrRewindView;
}

#pragma mark - 销毁
- (void)dealloc {
    [self removeAllObserver];
}
@end
