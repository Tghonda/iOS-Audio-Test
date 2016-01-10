//
//  OFCSoundPlayer.h
//  OFCSoundPlayer
//
//  Created by 本田忠嗣 on 2016/01/10.
//  Copyright (c) 2015年 Orifice. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "OFCMemoryBuffer.h"

@interface OFCSoundGadget : NSObject

//- (id)initWithMemBuffer:(ECGSoundBuffer*)memBuf;
- (id)initWithMemBuffer:(OFCMemoryBuffer*)memBuf;
- (void)rec;
- (void)play;
- (void)stop;
- (void)setIgnoreSilent:(int32_t)count;

@end
