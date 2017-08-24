//
//  CMAllMediaAudioManager.h
//  CmosAllMedia
//
//  Created by 王智垚 on 2017/8/22.
//  Copyright © 2017年 liangscofield. All rights reserved.
//  音频播放

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface CMAllMediaAudioManager : NSObject
/** 初始化单例 **/
+ (CMAllMediaAudioManager *)sharedInstance;

/** 开始播放 **/
@property (nonatomic, copy)void(^audioStartBlock)();
/** 暂停播放 **/
@property (nonatomic, copy)void(^audioPauseBlock)();
/** 停止播放 **/
@property (nonatomic, copy)void(^audioStopBlock)();
/** 播放完成 **/
@property (nonatomic, copy)void(^audioFinishBlock)();

/**
 *  播放音频文件
 *
 *  @param urlPath   音频地址
 *  @param isLocalFileType 是否来自本地源文件
 *  @param isLoudspeaker 是否扬声器播放
 */
- (void)manageAudioWithUrlPath:(NSString *)urlPath audioIsLocalFileType:(BOOL)isLocalFileType audioIsLoudspeaker:(BOOL)isLoudspeaker andShowView:(UIView *)showView;

/** 暂停播放 **/
- (void)pauseAudio;
/** 停止播放 **/
- (void)stopAudio;

/** 清除所有本地缓存视频文件 **/
+ (void)clearAllAudioCache;
@end
