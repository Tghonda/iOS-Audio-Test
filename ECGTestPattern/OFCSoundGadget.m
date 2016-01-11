//
//  OFCSoundGadget.m
//  OFCSoundGadget
//
//  Created by 本田忠嗣 on 2016/01/10.
//  Copyright (c) 2016年 Orifice. All rights reserved.
//

#import "OFCSoundGadget.h"


#define kNumberBuffers	3
#define kSamplesPerBuf	1024
#define kSamplingRate   44100

// config.
const static Float32 kLimitSilentLevel = 20.0;

@interface OFCSoundGadget()
{
    BOOL isPlaying;
    BOOL isRecording;
    int32_t isIgnoreSilent;
    AudioQueueRef _aQueIn;
    AudioQueueRef _aQueOut;
    AudioQueueBufferRef _buffersIn[kNumberBuffers];
    AudioQueueBufferRef _buffersOut[kNumberBuffers];
}

@property (nonatomic) OFCMemoryBuffer* memBuf;
//@property (nonatomic) ECGSoundBuffer* memBuf;

@end

@implementation OFCSoundGadget


static void callbackOut(
                        void                 *inUserData,
                        AudioQueueRef        inAQ,
                        AudioQueueBufferRef  inBuffer)
{
    OFCSoundGadget    *ref = (__bridge OFCSoundGadget *)inUserData;
    
    //    NSLog(@"CB Out");
    inBuffer->mAudioDataByteSize = [ref->_memBuf popData:inBuffer->mAudioData
                                    :kSamplesPerBuf * sizeof(Float32)];
#if 0
    inBuffer->mAudioDataByteSize = [ref->_memBuf popDataBlocking:inBuffer->mAudioData
                                                                   :kSamplesPerBuf * sizeof(Float32): 0.1];
#endif
    inBuffer->mPacketDescriptionCount = inBuffer->mAudioDataByteSize/sizeof(Float32);
    
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}


static void callbackIn(
                       void                                *inUserData,
                       AudioQueueRef                       inAQ,
                       AudioQueueBufferRef                 inBuffer,
                       const AudioTimeStamp                *inStartTime,
                       UInt32                              inNumberPacketDescriptions,
                       const AudioStreamPacketDescription  *inPacketDescs)
{
    OFCSoundGadget    *ref = (__bridge OFCSoundGadget *)inUserData;
    
    //    NSLog(@"CB In:%ld", inBuffer->mAudioDataByteSize);
    if (!ref->isIgnoreSilent) {
//        [ref->_memBuf pushData:inBuffer->mAudioData :inBuffer->mAudioDataByteSize];
        [ref->_memBuf pushData:inBuffer->mAudioData :inBuffer->mAudioDataByteSize];
    }
    else {
        Float32 *pcm = (Float32*)inBuffer->mAudioData;
        Float32 pow = 0.0;
        for (int i=0; i<inBuffer->mAudioDataByteSize/sizeof(Float32); i++) {
            pow += fabsf(*pcm);
            pcm++;
        }
        NSLog(@" POW:%f", pow);
        if (pow > kLimitSilentLevel)
            ref->isIgnoreSilent--;
    }
    
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}

-(id)initWithMemBuffer:(OFCMemoryBuffer*)memBuf
//-(id)initWithMemBuffer:(ECGSoundBuffer*)memBuf
{
    self = [super init];
    
    if (self == nil) {
        return nil;
    }
    
    isPlaying = false;
    isRecording = false;
    _memBuf = memBuf;
    
    // オーディオフォーマット
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate         = kSamplingRate;
    audioFormat.mFormatID           = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags        = kAudioFormatFlagIsFloat;
    audioFormat.mFramesPerPacket    = 1;
    audioFormat.mChannelsPerFrame   = 1;
    audioFormat.mBitsPerChannel     = 8 * sizeof(Float32);
    audioFormat.mBytesPerPacket     = sizeof(Float32);
    audioFormat.mBytesPerFrame      = sizeof(Float32);
    audioFormat.mReserved           = 0;
    
    // AudioQueue 作成
    AudioQueueNewInput(&audioFormat, &callbackIn, (void *)CFBridgingRetain(self), NULL, NULL, 0, &_aQueIn);
    AudioQueueNewOutput(&audioFormat, &callbackOut, (void *)CFBridgingRetain(self), NULL, NULL, 0, &_aQueOut);
    
    // バッファーをアロケート
    UInt32  bufSize = kSamplesPerBuf * sizeof(Float32);
    for (int idx = 0; idx < kNumberBuffers; idx++) {
        AudioQueueAllocateBuffer(_aQueIn, bufSize, &_buffersIn[idx]);
    }
    
    for (int idx = 0; idx < kNumberBuffers; idx++) {
        AudioQueueAllocateBuffer(_aQueOut, bufSize, &_buffersOut[idx]);
    }
    
    return self;
}

-(void)dealloc
{
    AudioQueueDispose(_aQueIn, YES);
    AudioQueueDispose(_aQueOut, YES);
}

-(void)rec
{
    if (isRecording)
        return;
    
    isRecording = true;
    // 先頭に巻き戻す
//    [self.memBuf rewindPush];
    
    for (int idx = 0; idx < kNumberBuffers; idx++) {
        AudioQueueEnqueueBuffer(_aQueIn, _buffersIn[idx], 0, NULL);
    }
    AudioQueueStart(_aQueIn, NULL);
}

-(void)play
{
    if (isPlaying) {
        [self stop];
    }
    isPlaying = true;
    
    // 先頭に巻き戻す
//    [self.memBuf rewindPop];
    
    for (int idx = 0; idx < kNumberBuffers; idx++) {
        [_memBuf popData:_buffersOut[idx]->mAudioData
                                   :kSamplesPerBuf * sizeof(Float32)];
        _buffersOut[idx]->mAudioDataByteSize = kSamplesPerBuf  * sizeof(Float32);
        AudioQueueEnqueueBuffer(_aQueOut, _buffersOut[idx], 0, NULL);
    }
    
    AudioQueueStart(_aQueOut, NULL);
}

-(void)stop
{
    AudioQueueStop(_aQueIn, YES);
    AudioQueueStop(_aQueOut, YES);
    AudioQueueFlush(_aQueOut);
    isRecording = isPlaying = false;
}

- (void)setIgnoreSilent:(int32_t)count
{
    isIgnoreSilent = count;
}
@end
