//
//  OFCMemoryBuffer.h
//  TestPlayPCMSound0
//
//  Created by 本田忠嗣 on 2016/01/10.
//  Copyright (c) 2015年 Orifice. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OFCMemoryBuffer : NSObject

- (id)initWithTotalSize:(int32_t)dataSize;
- (int32_t)pushData:(void*)buf :(int32_t) size;
- (int32_t)popData:(void*)buf :(int32_t) size;
- (void)rewindPush;
- (void)rewindPop;
- (void*)getBufferAddr;
- (int32_t)peekDataSize;

@end

@interface OFCRingBuffer : NSObject
- (id)initWithSize:(int32_t)bufferSize;
- (void)reset;
- (int32_t)pushData:(void*)buf :(int32_t) size;
- (int32_t)popDataBlocking:(void*)buf :(int32_t) size :(double) waitTime;
@end

@interface ECGSoundBuffer : OFCRingBuffer
- (id)initWithSize:(int32_t)ringBufferSize :(int32_t)linearBufferSize;
- (Float32*)getPCMList:(double)time;
- (void)reset;
@end

