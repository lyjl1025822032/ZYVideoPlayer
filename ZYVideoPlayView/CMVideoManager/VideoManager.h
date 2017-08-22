//
//  VideoManager.h
//  ZYVideoPlayView
//
//  Created by 王智垚 on 2017/8/21.
//  Copyright © 2017年 王智垚. All rights reserved.
//  视频播放器

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *const kPlayerStateChanged;
FOUNDATION_EXPORT NSString *const kPlayerProgressChanged;
FOUNDATION_EXPORT NSString *const kPlayerLoadProgressChanged;

typedef NS_ENUM(NSInteger, PlayerState) {
    PlayerStateBuffering = 1,    //正在缓存
    PlayerStatePlaying,          //正在播放
    PlayerStateStopped,          //播放结束
    PlayerStatePause,            //暂停播放
    PlayerStateFinish,           //播放完成
};

@interface VideoManager : NSObject
/** 视频Player状态 **/
@property (nonatomic, readonly) PlayerState state;
/** 缓冲的进度 **/
@property (nonatomic, readonly) CGFloat loadedProgress;
/** 播放进度0~1之间 **/
@property (nonatomic, readonly) CGFloat progress;
/** 当前播放时间 **/
@property (nonatomic, readonly) CGFloat current;
/** 视频总时间 **/
@property (nonatomic, readonly) CGFloat duration;

/**是否后台播放，默认YES **/
@property (nonatomic, assign) BOOL stopInBackground;
/** 当前播放次数 **/
@property (nonatomic, assign) NSInteger playCount;
/** 重复播放次数 **/
@property (nonatomic, assign) NSInteger playRepatCount;
/** 关闭按钮回调 **/
@property (nonatomic, copy)void(^closeBtnBlock)();
/** 进入媒体库按钮 **/
@property (nonatomic, copy)void(^enterMediaBlock)();

/** 初始化单例 **/
+ (instancetype)sharedInstance;
/**
 *  播放服务器的视频，先判断本地是否有缓存文件(有就直接播放)，缓存文件名为连接的url生成的字符串
 *  @param url       视频Url
 *  @param showView  显示的View
 *  @param superView 当前显示页
 */
- (void)playWithUrl:(NSURL *)url showView:(UIView *)showView andSuperView:(UIView *)superView;

/** 指定到某一时间点开始播放 **/
- (void)seekToTime:(CGFloat)seconds;

/** 恢复播放 **/
- (void)resume;

/** 暂停播放 **/
- (void)pause;

/** 停止播放 **/
- (void)stop;

/** 全屏 **/
- (void)fullScreenClicked;

/** 隐藏工具条 **/
- (void)toolViewHidden;

/** 显示工具条 **/
- (void)showToolView;

/** 清除所有本地缓存视频文件 **/
+ (void)clearAllVideoCache;
@end
