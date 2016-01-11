//
//  OFCMemoryBuffer.m
//  TestPlayPCMSound0
//
//  Created by 本田忠嗣 on 2016/01/10.
//  Copyright (c) 2016年 Orifice. All rights reserved.
//

#import "OFCMemoryBuffer.h"

@interface OFCMemoryBuffer()
{
    void*	_data;
    int32_t	_totalSize;
    int32_t	_popPosition;
    int32_t	_pushPosition;
}

@property (nonatomic) int32_t totalSize;
@property (nonatomic) int32_t readPosition;
@property (nonatomic) int32_t writePosition;

@end

@implementation OFCMemoryBuffer

-(id)initWithTotalSize:(int32_t)dataSize
{
    if (dataSize <= 0) {
        return nil;
    }
    
    self = [super init];
    if ( !self ) {
        return nil;
    }
    
    _data = malloc(dataSize);
    if ( !_data ) {
        return nil;
    }
    
    _totalSize = dataSize;
    _popPosition = 0;
    _pushPosition = 0;
    
    return self;
}

- (void)dealloc
{
    if (_data) {
        free(_data);
    }
    //	[super dealloc];		// ARC では super を呼び出してはいけない！（コンパイラーが自動生成する）
}

-(int32_t)pushData:(void*)buf :(int32_t)size
{
    int32_t len = _totalSize - _pushPosition;
    if (size > len) {
        size = len;
    }

    memcpy(_data+_pushPosition, buf, size);
    _pushPosition += size;
    return size;
}

-(int32_t)popData:(void*)buf :(int32_t)size
{
    int32_t len = _pushPosition - _popPosition;
    if (size > len) {
        size = len;
    }
    
    memcpy(buf, _data+_popPosition, size);
    _popPosition += size;
    return size;
}

-(void)rewindPush
{
    _pushPosition = 0;
}

-(void)rewindPop
{
    _popPosition = 0;
}

-(void*)getBufferAddr
{
    return _data;
}

-(int32_t)peekDataSize
{
    return _pushPosition;
}

@end

/*******************************************************************
	Sound Buffer for ECG.
		super class is OFCRingBuffer.

	memo sigma=2.0 -> dx:263
		 sigma=4.0 -> dx:535
*/
@interface ECGSoundBuffer()
{
//	OFCRingBuffer*		_ringBuffer;		// inherited
	Float32*	_PCMBuffer;
	int32_t		_dxMargin;
	int32_t		_validData;
	int32_t		_offsetbase;
	int32_t		_bufferLength;
    int32_t		_maxSamples;
	BOOL		_isPllLocked;
}

@end

@implementation ECGSoundBuffer

static Float32 kSamplingRate = 44100.0;

-(id)initWithSize:(int32_t)ringBufferSize :(int32_t)linearBufferSize
{
	if (ringBufferSize <= 0)	return nil;
    
	self = [super initWithSize:ringBufferSize];
	if ( !self ) return nil;

	_PCMBuffer = (Float32*)malloc(linearBufferSize);
	if ( !_PCMBuffer ) {
		_PCMBuffer = nil;		// need dealloc?
		return nil;
	}
    
	_dxMargin		= 300;			// must be ">263" at sigma is 2.0.
	_validData		= 0;
	_offsetbase		= 0;
	_bufferLength	= linearBufferSize;
    _maxSamples     = _bufferLength/sizeof(Float32);
	_isPllLocked	= NO;

    return self;
}

- (void)dealloc
{
    if (_PCMBuffer) {
        free(_PCMBuffer);
    }
}

- (void)reset
{
    [super reset];
    _validData		= 0;
    _offsetbase		= 0;
	_isPllLocked	= NO;
}

- (Float32*)getPCMList:(double)time
{
    int32_t timePosition = time*kSamplingRate + _dxMargin - _offsetbase;
	if (timePosition < (_validData - _dxMargin)) {
		if (timePosition < _dxMargin) {
			printf("Error! Under Position\n");
			timePosition = _dxMargin;
		}
        NSLog(@"PCM 0 %d", timePosition);
		return &(_PCMBuffer[timePosition]);
	}

	int32_t fillsize = timePosition + _dxMargin - _validData;
	while ( fillsize ) {
		if ( _validData + fillsize > _maxSamples) {
			int32_t rLen = _maxSamples - _validData;
			[self popDataBlocking:&_PCMBuffer[_validData] :rLen*sizeof(Float32) : 1.0];
			fillsize -= rLen;
			_validData += rLen;
			// バッファーいっぱいに詰め込んだ状態

			int32_t remainSize = (kSamplingRate * 50)/1000;		// 50msec
			if ( _isPllLocked )	remainSize = 0;
			remainSize += _dxMargin * 2;
			int32_t shiftLen = _maxSamples - remainSize;
			memmove(_PCMBuffer, &_PCMBuffer[shiftLen], remainSize*sizeof(Float32));
			_offsetbase += shiftLen;
			_validData -= shiftLen;
            timePosition -= shiftLen;
		}
		else {
			[self popDataBlocking:&_PCMBuffer[_validData] :fillsize*sizeof(Float32): 1.0];
            _validData += fillsize;
			fillsize -= fillsize;
		}
	}
	return &_PCMBuffer[timePosition];
}

@end

/*******************************************************************
	Ring Buffer.
*/
@interface OFCRingBuffer()
{
	void*		_buffer;
	int32_t		_pushCount;
	int32_t		_popCount;
	int32_t		_bufferLength;

}

@end

@implementation OFCRingBuffer
- (id)initWithSize:(int32_t)bufferSize
{
	if ( !(self = [super init]) ) return nil;

	_buffer = malloc(bufferSize);
	if ( !_buffer )	return nil;

	memset(_buffer, 0, bufferSize);
	_pushCount = 0;
	_popCount = 0;
	_bufferLength = bufferSize;

	return self;
}

- (void)dealloc
{
    if (_buffer) {
        free(_buffer);
    }
}

- (void)reset
{
    _pushCount = 0;
    _popCount = 0;
}

- (int32_t)pushData:(void*)buf :(int32_t) size
{
    if ( _bufferLength < (_pushCount - _popCount) + size ){
        NSLog(@"Ring buffer Overflow !!!!");
		return -1;		// Over fllow!
    }
	int32_t rsize = size;
	int32_t tailLength = _bufferLength - (_pushCount % _bufferLength);
	if (size > tailLength) {
		memcpy(_buffer+(_pushCount % _bufferLength), buf, tailLength);
		size -= tailLength;
		buf  += tailLength;
		_pushCount += tailLength;
	}
	memcpy(_buffer+(_pushCount % _bufferLength), buf, size);
	_pushCount += size;

	return rsize;
}

- (int32_t)popDataBlocking:(void*)buf :(int32_t)size :(double)waitTime
{
	// config.
	static double waitTics = 30.0/1000.0;

    while (size > (_pushCount - _popCount)) {
		[NSThread sleepForTimeInterval:waitTics];
		waitTime -= waitTics;
        if (waitTime < 0) {
            return -1;		// internal error!
        }
	}

	int32_t rsize = size;
	int32_t tailLength = _bufferLength - (_popCount % _bufferLength);
	if (size > tailLength) {
		memcpy(buf, _buffer+(_popCount % _bufferLength), tailLength);
		size -= tailLength;
		buf  += tailLength;
		_popCount += tailLength;
	}
	memcpy(buf, _buffer+(_popCount % _bufferLength), size);
	_popCount += size;

	return rsize;
}

@end

#if 0
/*******************************************************************
	Linear Buffer.
*/
@interface OFCLinearBuffer()
{
	void* _buffer;
	int _bufferLength;
}

@end

@implementation OFCLinearBuffer
- (id)initWithSize:(int32_t)bufferSize
{
	if ( !(self = [super init]) ) return nil;

	_buffer = malloc(bufferSize);
	if ( !_buffer )	return nil;

	memset(_buffer, 0, bufferSize);
	_bufferLength = bufferSize;

	return self;
}

- (void)pushTail:(void*)buf :(int32_t) size
{
	if (size > _bufferLength) {
		buf += size - _bufferLength;
		memcpy(_buffer, buf, _bufferLength);
		return;
	}
	memmove(_buffer, _buffer+size, _bufferLength - size);
	memcpy(_buffer + (_bufferLength - size), buf, size);
}

- (void)pushHead:(void*)buf :(int32_t) size
{
	if (size > _bufferLength) {
		memcpy(_buffer, buf, _bufferLength);
		return;
	}
	memmove(_buffer+size, _buffer, _bufferLength - size);
	memcpy(_buffer, buf, size);
}

@end
#endif
