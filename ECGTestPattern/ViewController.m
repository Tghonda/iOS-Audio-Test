//
//  ViewController.m
//  ECGTestPattern
//
//  Created by 本田忠嗣 on 2016/01/10.
//  Copyright (c) 2016年 Orifice. All rights reserved.
//

#import "ViewController.h"
#import "OFCMemoryBuffer.h"
#import "OFCSoundGadget.h"


const static double kSamplingFrequency = 44100.0;

@interface ViewController ()
{
    double currentTime;
    double lastPhase;
    int32_t pcmIdx;
    int32_t serialno;
}

@property (nonatomic) OFCSoundGadget* pcmPlayer;
@property (nonatomic) OFCMemoryBuffer* pcmBuffer;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    int32_t pcmBufSize = sizeof(Float32) * kSamplingFrequency * 40;
    self.pcmBuffer = [[OFCMemoryBuffer alloc] initWithTotalSize:pcmBufSize];

    // Sound In/Out
    self.pcmPlayer = [[OFCSoundGadget alloc] initWithMemBuffer: self.pcmBuffer];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)clickPat1:(id)sender {
    [_pcmPlayer stop];
    
    currentTime = 0.0;
    lastPhase = 0.0;
    pcmIdx = 0;
    serialno = 0xAA44AA;
    [_pcmBuffer rewindPush];
    [_pcmBuffer rewindPop];
    
    [self genPattern1];
    [_pcmPlayer play];
}

- (IBAction)clickPat2:(id)sender {
    [_pcmPlayer stop];
    
    currentTime = 0.0;
    lastPhase = 0.0;
    pcmIdx = 0;
    serialno = 0x0F0F0F;
    [_pcmBuffer rewindPush];
    [_pcmBuffer rewindPop];
    
    [self genPattern2];
    [_pcmPlayer play];
}

- (IBAction)clickStop:(id)sender {
    [_pcmPlayer stop];
}

- (void) genPattern2
{
    int i, j;
    double freq;
    
    [self genHedders];

    for (i=0; i<100; i++) {
        [self genPCM:1200+i*10: 1000.0/(450.0)*10];
    }
    
    for (i=0; i<10; i++) {
        [self genPCM:1200+i*100: 1000.0/(450.0)*10];
    }
}

- (void) genPattern1
{
    int i;
    double freq;
    
    [self genHedders];
    
    // Data
    for (i=0; i<1000; i+=2) {
        [self genPCM:1200+i: 1000.0/(450.0)];
    }
    for (i=1000; i>0; i-=2) {
        [self genPCM:1200+i: 1000.0/(450.0)];
    }
    
    for (i=0; i<100; i++) {
        [self genPCM:1700-500: 1000.0/(450.0) *2];
        [self genPCM:1700+500: 1000.0/(450.0) *2];
    }
    for (i=0; i<100; i++) {
        [self genPCM:1700-400: 1000.0/(450.0) *2];
        [self genPCM:1700+400: 1000.0/(450.0) *2];
    }
    for (i=0; i<100; i++) {
        [self genPCM:1700-300: 1000.0/(450.0) *2];
        [self genPCM:1700+300: 1000.0/(450.0) *2];
    }
    for (i=0; i<100; i++) {
        [self genPCM:1700-200: 1000.0/(450.0) *2];
        [self genPCM:1700+200: 1000.0/(450.0) *2];
    }
    for (i=0; i<100; i++) {
        [self genPCM:1700-100: 1000.0/(450.0) *2];
        [self genPCM:1700+100: 1000.0/(450.0) *2];
    }
    for (i=0; i<100; i++) {
        [self genPCM:1700: 1000.0/(450.0)];
        [self genPCM:1700: 1000.0/(450.0)];
    }
    
    for (i=0; i<2300; i++) {
        freq = 1700.0 + sin(2.0*M_PI*8*i/2300.0) * 500.0*(1.0 - i/2300.0);
        [self genPCM:freq: 1000.0/(450.0)];
    }
    
    for (i=0; i<10; i++) {
        [self genPCM:1200+i*100: 100];
    }
    for (i=0; i<10; i++) {
        [self genPCM:1200+i*100: 100];
    }
    for (i=0; i<10; i++) {
        [self genPCM:2200-i*100: 100];
    }
    
    [self genPCM:1400: 300];
    [self genPCM:1600: 300];
    [self genPCM:1800: 300];
    [self genPCM:2000: 300];
}

- (void) genHedders
{
    int i;
    double freq, f;
    
    // Lead
    [self genPCM:0.0 :260.0];
    [self genPCM:1200.0: 40.0];
    
    //  Header
    double t = 1000.0/225.0 /2;
    for (f=0.0; f<510.0; f += t) {
        freq = f*1000.0 / 510.0 + 1200.0;
        [self genPCM:freq: (double)t];
    }
    [self genPCM:2240.0: 28.0];
    
    // Calibration
    for (i=0; i<18; i++) {
        [self genPCM:1800.0: 40.0];
        [self genPCM:1700.0: 40.0];
        [self genPCM:1600.0: 40.0];
    }
    
    // Serial No
    for (i=0; i<24; i++) {
        freq = 1700.0 + ((serialno & (1<<i))? 335.0 : -335.0);
        [self genPCM:freq: 80.0];
    }
    int chksum = ((serialno>>16) & 0xFF) + ((serialno>>8) & 0xFF) + (serialno & 0xFF);
    for (i=0; i<16; i++) {
        freq = 1700.0 + ((chksum & (1<<i))? 335.0 : -335.0);
        [self genPCM:freq: 80.0];
    }
}

- (void) genPCM:(double)freq :(double) duration
{
    int i;
    double t;
    float  pcm[2];
    
    currentTime += duration/1000.0;		// duration (msec)
    int currentPosi = (kSamplingFrequency * currentTime);
    
    i = 0;
    while (pcmIdx < currentPosi) {
        t = 2.0*M_PI * freq * (double)(i) / 44100.0;
        pcm[0] = (float)sin( t + lastPhase) * 0.5;
        [_pcmBuffer pushData:pcm :sizeof(float)];
        pcmIdx++;
        i++;
    }
    lastPhase = 2.0*M_PI * freq * (double)(i) / 44100.0 + lastPhase;
}

@end
