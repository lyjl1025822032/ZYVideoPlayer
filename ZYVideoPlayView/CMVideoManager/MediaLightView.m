//
//  MediaLightView.m
//  ZYVideoPlayView
//
//  Created by 王智垚 on 2017/8/21.
//  Copyright © 2017年 王智垚. All rights reserved.
//

#import "MediaLightView.h"

@interface MediaLightView ()
@property (nonatomic, strong) UIImageView		*backImage;
@property (nonatomic, strong) UILabel			*title;
@property (nonatomic, strong) UIView			*brightnessLevelView;
@property (nonatomic, strong) NSMutableArray	*tipArray;
@property (nonatomic, strong) NSTimer			*timer;
@end

@implementation MediaLightView
+ (instancetype)sharedInstance {
    static MediaLightView *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MediaLightView alloc] init];
        [[UIApplication sharedApplication].windows.firstObject addSubview:instance];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        self.frame = CGRectMake(kScreenWidth * 0.5, kScreenHeight * 0.5, 155, 155);
        
        self.layer.cornerRadius  = 10;
        self.layer.masksToBounds = YES;
        
        // 使用UIToolbar实现毛玻璃效果，简单粗暴，支持iOS7+
        UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:self.bounds];
        toolbar.alpha = 0.97;
        [self addSubview:toolbar];
        
        [self addSubview:self.backImage];
        [self addSubview:self.title];
        [self addSubview:self.brightnessLevelView];
        
        [self createTips];
        [self addNotification];
        [self addObserver];
        
        self.alpha = 0.0;
    }
    return self;
}

- (void)setupUI {
    
}

#pragma makr - 创建 Tips
- (void)createTips {
    self.tipArray = [NSMutableArray arrayWithCapacity:16];
    CGFloat tipW = (self.brightnessLevelView.bounds.size.width - 17) / 16;
    CGFloat tipH = 5;
    CGFloat tipY = 1;
    
    for (int i = 0; i < 16; i++) {
        CGFloat tipX   = i * (tipW + 1) + 1;
        UIImageView *image    = [[UIImageView alloc] init];
        image.backgroundColor = [UIColor whiteColor];
        image.frame           = CGRectMake(tipX, tipY, tipW, tipH);
        [self.brightnessLevelView addSubview:image];
        [self.tipArray addObject:image];
    }
    [self updateLightLevel:[UIScreen mainScreen].brightness];
}

#pragma makr - 通知 KVO
- (void)addNotification {
    //用来监测屏幕旋转
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)addObserver {
    [[UIScreen mainScreen] addObserver:self forKeyPath:@"brightness" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    CGFloat levelValue = [change[@"new"] floatValue];
    [self removeTimer];
    [self appearLightView];
    [self updateLightLevel:levelValue];
}

#pragma mark - 方向改变通知
- (void)orientationChanged:(NSNotification *)notify {
    [self setNeedsLayout];
}

#pragma mark - lightview显示 隐藏
- (void)appearLightView {
    [UIView animateWithDuration:0.5 animations:^{
        self.alpha = 1;
    } completion:^(BOOL finished) {
        [self addtimer];
    }];
}

- (void)disAppearLightView {
    if (self.alpha == 1.0) {
        [UIView animateWithDuration:0.5 animations:^{
            self.alpha = 0.0;
        } completion:^(BOOL finished) {
            [self removeTimer];
        }];
    }
}

#pragma mark - 定时器
- (void)addtimer {
    if (self.timer) {
        return;
    }
    self.timer = [NSTimer timerWithTimeInterval:2 target:self selector:@selector(disAppearLightView) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
}

- (void)removeTimer {
    [self.timer invalidate];
    self.timer = nil;
}

#pragma mark - 更新亮度值
- (void)updateLightLevel:(CGFloat)brightnessLevel {
    CGFloat stage = 1 / 15.0;
    NSInteger level = brightnessLevel / stage;
    for (int i = 0; i < self.tipArray.count; i++) {
        UIImageView *img = self.tipArray[i];
        if (i <= level) {
            img.hidden = NO;
        } else {
            img.hidden = YES;
        }
    }
}

#pragma mark - 更新布局
- (void)layoutSubviews {
    [super layoutSubviews];
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    switch (orientation) {
        case UIDeviceOrientationPortrait:
        case UIDeviceOrientationPortraitUpsideDown:
            self.center = CGPointMake(kScreenWidth * 0.5, (kScreenHeight - 10) * 0.5);
            break;
        case UIDeviceOrientationLandscapeLeft:
        case UIDeviceOrientationLandscapeRight:
            self.center = CGPointMake(kScreenHeight * 0.5, kScreenWidth * 0.5);
            break;
        default:
            break;
    }
    self.backImage.center = CGPointMake(155 * 0.5, 155 * 0.5);
    [self.superview bringSubviewToFront:self];
}

#pragma mark - 懒加载
-(UILabel *)title {
    if (!_title) {
        _title = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, self.bounds.size.width, 30)];
        _title.font = [UIFont boldSystemFontOfSize:16];
        _title.textColor = [UIColor colorWithRed:0.25f green:0.22f blue:0.21f alpha:1.00f];
        _title.textAlignment = NSTextAlignmentCenter;
        _title.text = @"亮度";
    }
    return _title;
}

- (UIImageView *)backImage {
    if (!_backImage) {
        _backImage = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 79, 76)];
        _backImage.image = kVideoViewPicName(@"icon_brightness");
    }
    return _backImage;
}

- (UIView *)brightnessLevelView {
    if (!_brightnessLevelView) {
        _brightnessLevelView  = [[UIView alloc]initWithFrame:CGRectMake(13, 132, self.bounds.size.width - 26, 7)];
        _brightnessLevelView.backgroundColor = [UIColor colorWithRed:0.25f green:0.22f blue:0.21f alpha:1.00f];
        [self addSubview:_brightnessLevelView];
    }
    return _brightnessLevelView;
}

#pragma mark - 销毁
- (void)dealloc {
    [[UIScreen mainScreen] removeObserver:self forKeyPath:@"brightness"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
