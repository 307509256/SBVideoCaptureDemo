//
//  SBVideoRecorder.m
//  SBVideoCaptureDemo
//
//  Created by Pandara on 14-8-13.
//  Copyright (c) 2014年 Pandara. All rights reserved.
//

#import "SBVideoRecorder.h"
#import "SBCaptureDefine.h"

@interface SBVideoData: NSObject

@property (assign, nonatomic) CGFloat duration;
@property (strong, nonatomic) NSURL *fileURL;

@end

@implementation SBVideoData

@end

#define COUNT_DUR_TIMER_INTERVAL 0.01

@interface SBVideoRecorder ()

@property (strong, nonatomic) NSTimer *countDurTimer;
@property (assign, nonatomic) CGFloat currentVideoDur;
@property (assign, nonatomic) NSURL *currentFileURL;
@property (assign ,nonatomic) CGFloat totalVideoDur;

@property (strong, nonatomic) NSMutableArray *videoFileDataArray;

@end

@implementation SBVideoRecorder

- (id)init
{
    self = [super init];
    if (self) {
        [self initalize];
    }
    
    return self;
}

- (void)initalize
{
    [self initCapture];
    
    self.videoFileDataArray = [[NSMutableArray alloc] init];
    self.totalVideoDur = 0.0f;
}

- (void)initCapture
{
    //session---------------------------------
    self.captureSession = [[AVCaptureSession alloc] init];
    
    //input
    self.inputDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    self.captureInput = [AVCaptureDeviceInput deviceInputWithDevice:_inputDevice error:nil];
    [_captureSession addInput:_captureInput];
    
    //output
    self.movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    [_captureSession addOutput:_movieFileOutput];
    
    //preset
    _captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    
    //preview layer------------------
    self.preViewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_captureSession];
    _preViewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    [_captureSession startRunning];
}

- (void)startCountDurTimer
{
    self.countDurTimer = [NSTimer scheduledTimerWithTimeInterval:COUNT_DUR_TIMER_INTERVAL target:self selector:@selector(onTimer:) userInfo:nil repeats:YES];
}

- (void)onTimer:(NSTimer *)timer
{
    self.currentVideoDur += COUNT_DUR_TIMER_INTERVAL;
    
    if ([_delegate respondsToSelector:@selector(videoRecorder:didRecordingToOutPutFileAtURL:duration:recordedVideosTotalDur:)]) {
        [_delegate videoRecorder:self didRecordingToOutPutFileAtURL:_currentFileURL duration:_currentVideoDur recordedVideosTotalDur:_totalVideoDur];
    }
    
    if (_totalVideoDur + _currentVideoDur >= MAX_VIDEO_DUR) {
        [self stopRecording];
    }
}

- (void)stopCountDurTimer
{
    [_countDurTimer invalidate];
    self.countDurTimer = nil;
}

#pragma mark - Method
//总时长
- (CGFloat)getTotalVideoDuration
{
    return _totalVideoDur;
}

//现在录了多少视频
- (int)getVideoCount
{
    return [_videoFileDataArray count];
}

- (void)startRecordingToOutputFileURL:(NSURL *)fileURL
{
    if (_totalVideoDur >= MAX_VIDEO_DUR) {
        NSLog(@"视频总长达到最大");
        return;
    }
    
    [_movieFileOutput startRecordingToOutputFileURL:fileURL recordingDelegate:self];
}

- (void)stopRecording
{
    [_movieFileOutput stopRecording];
}

//不调用delegate
- (void)deleteAllVideo
{
    for (SBVideoData *data in _videoFileDataArray) {
        NSURL *videoFileURL = data.fileURL;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *filePath = [[videoFileURL absoluteString] stringByReplacingOccurrencesOfString:@"file://" withString:@""];
            
            NSFileManager *fileManager = [NSFileManager defaultManager];
            if ([fileManager fileExistsAtPath:filePath]) {
                NSError *error = nil;
                [fileManager removeItemAtPath:filePath error:&error];
                
                if (error) {
                    NSLog(@"deleteAllVideo删除视频文件出错:%@", error);
                }
            }
        });
    }
}

//会调用delegate
- (void)deleteLastVideo
{
    if ([_videoFileDataArray count] == 0) {
        return;
    }
    
    SBVideoData *data = (SBVideoData *)[_videoFileDataArray lastObject];
    
    NSURL *videoFileURL = data.fileURL;
    CGFloat videoDuration = data.duration;
    
    [_videoFileDataArray removeLastObject];
    _totalVideoDur -= videoDuration;
    
    //delete
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *filePath = [[videoFileURL absoluteString] stringByReplacingOccurrencesOfString:@"file://" withString:@""];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:filePath]) {
            NSError *error = nil;
            [fileManager removeItemAtPath:filePath error:&error];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                //delegate
                if ([_delegate respondsToSelector:@selector(videoRecorder:didRemoveVideoFileAtURL:totalDur:error:)]) {
                    [_delegate videoRecorder:self didRemoveVideoFileAtURL:videoFileURL totalDur:_totalVideoDur error:error];
                }
            });
        }
    });
}

#pragma mark - AVCaptureFileOutputRecordignDelegate
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    self.currentFileURL = fileURL;
    
    self.currentVideoDur = 0.0f;
    [self startCountDurTimer];
    
    if ([_delegate respondsToSelector:@selector(videoRecorder:didStartRecordingToOutPutFileAtURL:)]) {
        [_delegate videoRecorder:self didStartRecordingToOutPutFileAtURL:fileURL];
    }
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    [self stopCountDurTimer];
    self.totalVideoDur += _currentVideoDur;
    NSLog(@"本段视频长度: %f", _currentVideoDur);
    NSLog(@"现在的视频总长度: %f", _totalVideoDur);
    
    if (!error) {
        SBVideoData *data = [[SBVideoData alloc] init];
        data.duration = _currentVideoDur;
        data.fileURL = outputFileURL;
        
        [_videoFileDataArray addObject:data];
    }
    
    if ([_delegate respondsToSelector:@selector(videoRecorder:didFinishRecordingToOutPutFileAtURL:duration:totalDur:error:)]) {
        [_delegate videoRecorder:self didFinishRecordingToOutPutFileAtURL:outputFileURL duration:_currentVideoDur totalDur:_totalVideoDur error:error];
    }
}

@end
