/*
     File: MyViewController.mm
 Abstract: Main view controller for this sample.
  Version: 1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2012 Apple Inc. All Rights Reserved.
 
 */

#import "MyViewController.h"
#import "CaptureSessionController.h"


@interface MyViewController ()
@property (readonly, nonatomic) IBOutlet UIButton *startButton;
@property (readonly, nonatomic) IBOutlet UILabel *playbackText;
@property (nonatomic, strong) IBOutlet CaptureSessionController *captureSessionController;

- (IBAction)buttonAction:(id)sender;
@end

@implementation MyViewController

- (void)viewDidLoad
{
	[super viewDidLoad];

    m_currentMode = PRACTICE_MODE; // 預設為 練習 模式

    // set up the start button
    // we've also set up different button titles in IB depending on state etc.
    UIImage *greenImage = [[UIImage imageNamed:@"green_button.png"] stretchableImageWithLeftCapWidth:12.0 topCapHeight:0.0];
	UIImage *redImage = [[UIImage imageNamed:@"red_button.png"] stretchableImageWithLeftCapWidth:12.0 topCapHeight:0.0];

	[self.startButton setBackgroundImage:greenImage forState:UIControlStateNormal];
	[self.startButton setBackgroundImage:redImage forState:UIControlStateSelected];

    // 創建資料庫
    [self initDatabase];

    //m_listener = [SCListener sharedListener];
    //[m_listener listen];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return (toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)viewWillAppear:(BOOL)animated
{
    [self registerForNotifications];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self unregisterForNotifications];
}

#pragma mark ======== Capture Session =========

- (void)initCaptureSession
{
    if ([self.captureSessionController setupCaptureSession]) {
        [self updateUISelected:NO enabled:YES];
        
        m_pitchLists = [[NSMutableArray alloc] init];
    }
    else NSLog(@"Initializing CaptureSessionController failed just BAIL!");
}

// button starts and stops recording to the file
// capture session is running before button is enabled
- (IBAction)buttonAction:(id)sender
{
    // 停止錄音
    if (self.captureSessionController.isRecording) {

        // 停止 截取音頻訊號 的執行緒
        [timer invalidate];
        timer = nil;

        [self.captureSessionController stopRecording];
        [self updateUISelected:NO enabled:NO];

        if( m_currentMode == RECORD_MODE ) {

            [self playSampleRecordedAudio];
        } else {

            [self playRecordedAudio];
        }

        // 如是目前是 錄製樣本 模式，就將樣本存入資料庫
        if( m_currentMode == RECORD_MODE ) {

            // 儲存 音頻 至 DB
            for(NSUInteger i=0; i<[m_pitchLists count]; i++) {
                
                NSNumber *frequency = [m_pitchLists objectAtIndex:i];
                //NSLog(@"frequency:%@", frequency);
                [self SaveToDataBase:[frequency floatValue]];
            }
            
            // 取出樣本音頻
            NSMutableArray *samplePitchLists = [self loadSamplePitchLists];
            
            // 準備長條圖
            [self initBarChart:nil with:samplePitchLists];

        // 如是目前是 練習 模式，將樣本與資料庫資料進行音頻比對
        } else if( m_currentMode == PRACTICE_MODE ) {

            // 取出樣本音頻
            NSMutableArray *samplePitchLists = [self loadSamplePitchLists];

            // 準備長條圖
            [self initBarChart:m_pitchLists with:samplePitchLists];
            
            // 音頻比對
            [self frequencyComparison:m_pitchLists with:samplePitchLists];
        }

    // 開始錄音
    } else {

        // 如是目前是 錄製樣本 模式，就刪除舊樣本
        if( m_currentMode == RECORD_MODE ) {

            [self truncateDataBase];
            
            NSMutableArray *samplePitchLists = [self loadSamplePitchLists];
            NSLog(@"samplePitchLists(%d)", [samplePitchLists count]);
        }

        [self.captureSessionController startRecording:m_currentMode];
        [self updateUISelected:YES enabled:YES];

        [m_pitchLists removeAllObjects];
        
        // 另開執行緒，截取 音頻訊號
        timer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(updateTT:) userInfo:nil repeats:YES];
    }
}

// 取得音樂播放時間及更新動態歌詞
- (void)updateTT:(NSTimer*)TimeRecord
{
    NSNumber *frequency = [NSNumber numberWithFloat:0.0];
    double avg = 0.0f;
    if( audioPlayer.isPlaying ) {
    
        [audioPlayer updateMeters];
        double a = [audioPlayer averagePowerForChannel:0];
        double b = [audioPlayer averagePowerForChannel:1];
        avg = (a + b) / 2;

        //NSLog(@"avg(%f) = a(%f) + b(%f)", avg, a, b);
    } else {
        
        avg = [self.captureSessionController getAveragePowerLevel];
    }
    
    if( avg > -30 ) {

        frequency = [NSNumber numberWithFloat:self.captureSessionController->m_frequency];
    }
    
    NSLog(@"avg(%f) frequency(%@)", avg, frequency);
    [m_pitchLists addObject:frequency];

}

- (void)updateUISelected:(BOOL)selected enabled:(BOOL)enabled
{
    self.startButton.selected = selected;
    self.startButton.enabled = enabled;
}

#pragma mark ======== AVAudioPlayer =========

// when interrupted, just toss the player and we're done
- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player
{
    NSLog(@"AVAudioPlayer audioPlayerBeginInterruption");
    
    [player setDelegate:nil];
    [player release];
    
    self.playbackText.hidden = YES;
}

// when finished, toss the player and restart the capture session
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
	(flag == NO) ? NSLog(@"AVAudioPlayer unsuccessfull!") :
                   NSLog(@"AVAudioPlayer finished playing");

	[player setDelegate:nil];
    [player release];
    
    self.playbackText.hidden = YES;
    
    // start the capture session
    [self.captureSessionController startCaptureSession];
}

// basic AVAudioPlayer implementation to play back recorded file
- (void)playRecordedAudio
{
    NSError *error = nil;
    
    // stop the capture session
    [self.captureSessionController stopCaptureSession];
    
    NSLog(@"Playing Recorded Audio");
    
    // play the result
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:(NSURL *)self.captureSessionController.outputFile error:nil];
    if (nil == player) {
        NSLog(@"AVAudioPlayer alloc failed! %@", [error localizedDescription]);
        [self.startButton setTitle:@"FAIL!" forState:UIControlStateDisabled];
        return;
    }

    self.playbackText.hidden = NO;
    
    [player setDelegate:self];
    [player play];
}

- (void)playSampleRecordedAudio
{
    NSError *error = nil;
    
    // stop the capture session
    [self.captureSessionController stopCaptureSession];
    
    NSLog(@"Playing Recorded Audio");
    
    // play the result
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:(NSURL *)self.captureSessionController.sampleOutputFile error:nil];
    if (nil == player) {
        NSLog(@"AVAudioPlayer alloc failed! %@", [error localizedDescription]);
        [self.startButton setTitle:@"FAIL!" forState:UIControlStateDisabled];
        return;
    }
    
    self.playbackText.hidden = NO;
    
    [player setDelegate:self];
    [player play];
}

- (void)playVoiceSampleRecordedAudio
{
    // 停止 截取音頻訊號 的執行緒
    [timer invalidate];
    timer = nil;
    
    // 另開執行緒，截取 音頻訊號
    timer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(updateTT:) userInfo:nil repeats:YES];

    // stop the capture session
    //[self.captureSessionController stopCaptureSession];
    
    NSLog(@"Playing Recorded Audio");
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"3" ofType:@"m4a"];
    NSData *myData = [NSData dataWithContentsOfFile:filePath];
    if (myData) {

        audioPlayer = [[AVAudioPlayer alloc] initWithData:myData error:nil];
        audioPlayer.delegate = self;
        [audioPlayer prepareToPlay];
        audioPlayer.meteringEnabled = YES;
        [audioPlayer play];
        
    }
}

- (void)playSoundSequence
{
    NSLog(@"playSoundSequence");
    
}

#pragma mark ======== Notifications =========

// notification handling to do the right thing when the app comes and goes
- (void)registerForNotifications
{    
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(willResignActive)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(enableButton)
                                                 name:@"CaptureSessionRunningNotification"
                                               object:nil];
}

- (void)unregisterForNotifications
{
	[[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillResignActiveNotification
                                               object:nil];
    
	[[NSNotificationCenter defaultCenter] removeObserver:self
                                                 name:@"CaptureSessionRunningNotification"
                                               object:nil];
}

- (void)willResignActive
{
    NSLog(@"MyViewController willResignActive");
    
    [self updateUISelected:NO enabled:NO];
}

- (void)enableButton
{
    NSLog(@"MyViewController enableButton");
    
    [self updateUISelected:NO enabled:YES];
}


- (void)initDatabase
{
    /*根据路径创建数据库并创建一个表contact(id nametext addresstext phonetext)*/    
    NSString *docsDir;
    NSArray *dirPaths;

    // Get the documents directory
    dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    docsDir = [dirPaths objectAtIndex:0];

    // Build the path to the database file
    databasePath = [[NSString alloc] initWithString: [docsDir stringByAppendingPathComponent: @"sample.db"]];

    NSFileManager *filemgr = [NSFileManager defaultManager];

    if ([filemgr fileExistsAtPath:databasePath] == NO) {

        const char *dbpath = [databasePath UTF8String];
        if (sqlite3_open(dbpath, &contactDB)==SQLITE_OK) {

            char *errMsg;
            const char *sql_stmt = "CREATE TABLE IF NOT EXISTS SAMPLE(ID INTEGER PRIMARY KEY AUTOINCREMENT, FREQUENCY REAL)";
            if (sqlite3_exec(contactDB, sql_stmt, NULL, NULL, &errMsg)!=SQLITE_OK) {

                NSLog(@"创建表失败\n");
            } else {
                
                NSLog(@"创建表成功\n");
            }
        } else {

            NSLog(@"创建/打开数据库失败");
        }
    }    
}

- (void)SaveToDataBase:(float)value
{
    sqlite3_stmt *statement;

    const char *dbpath = [databasePath UTF8String];
    if (sqlite3_open(dbpath, &contactDB)==SQLITE_OK) {

        NSString *insertSQL = [NSString stringWithFormat:@"INSERT INTO SAMPLE (FREQUENCY) VALUES(\"%f\")",value];
        const char *insert_stmt = [insertSQL UTF8String];
        sqlite3_prepare_v2(contactDB, insert_stmt, -1, &statement, NULL);
        if (sqlite3_step(statement)==SQLITE_DONE) {

            //NSLog(@"已存储到数据库");
        } else {

            NSLog(@"保存失败");
        }

        sqlite3_finalize(statement);
        sqlite3_close(contactDB);
    }
}

- (void)SearchFromDataBase:(int)index
{
    const char *dbpath = [databasePath UTF8String];
    sqlite3_stmt *statement;

    if (sqlite3_open(dbpath, &contactDB) == SQLITE_OK) {

        NSString *querySQL = [NSString stringWithFormat:@"SELECT ID,FREQUENCY from SAMPLE where ID=\"%d\"",index];
        const char *query_stmt = [querySQL UTF8String];
        if (sqlite3_prepare_v2(contactDB, query_stmt, -1, &statement, NULL) == SQLITE_OK) {

            if (sqlite3_step(statement) == SQLITE_ROW) {

                int _index = sqlite3_column_int(statement, 0);
                float _frequency = sqlite3_column_double(statement, 1);
                NSLog(@"已查到结果: index(%d) frequency(%f)", _index, _frequency);
            } else {

                NSLog(@"未查到结果");
            }

            sqlite3_finalize(statement);
        }

        sqlite3_close(contactDB);
    }
}

- (NSMutableArray *)loadSamplePitchLists
{
    NSMutableArray *samplePitchList = [[NSMutableArray alloc] init];

    const char *dbpath = [databasePath UTF8String];
    sqlite3_stmt *statement;
    
    if (sqlite3_open(dbpath, &contactDB) == SQLITE_OK) {
        
        NSString *querySQL = [NSString stringWithFormat:@"SELECT FREQUENCY from SAMPLE where 1 ORDER BY ID ASC"];
        const char *query_stmt = [querySQL UTF8String];
        if (sqlite3_prepare_v2(contactDB, query_stmt, -1, &statement, NULL) == SQLITE_OK) {

            while (sqlite3_step(statement) == SQLITE_ROW) {

                float _frequency = sqlite3_column_double(statement, 0);
                NSNumber *frequency = [NSNumber numberWithFloat:_frequency];
                [samplePitchList addObject:frequency];
            }

            sqlite3_finalize(statement);
        }

        sqlite3_close(contactDB);
    }

    return [samplePitchList autorelease];
}


// 清除舊資料庫
- (void)truncateDataBase
{
    /*根据路径创建数据库并创建一个表contact(id nametext addresstext phonetext)*/
    NSString *docsDir;
    NSArray *dirPaths;
    
    // Get the documents directory
    dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    docsDir = [dirPaths objectAtIndex:0];
    
    // Build the path to the database file
    databasePath = [[NSString alloc] initWithString: [docsDir stringByAppendingPathComponent: @"sample.db"]];
    
         
    const char *dbpath = [databasePath UTF8String];
    if (sqlite3_open(dbpath, &contactDB)==SQLITE_OK) {
        
        char *errMsg;
        const char *sql_stmt = "DELETE FROM SAMPLE";
        if (sqlite3_exec(contactDB, sql_stmt, NULL, NULL, &errMsg)!=SQLITE_OK) {
            
            NSLog(@"清除資料庫失败\n");
        } else {
            
            NSLog(@"清除資料庫成功\n");
        }
    } else {
        
        NSLog(@"创建/打开数据库失败");
    }
}

- (IBAction)segmentedControlIndexChanged:(id)sender
{
    //利用獲得的選項Index來判斷所選項目
    switch ([sender selectedSegmentIndex]) {
        case 0:
            NSLog(@"錄製樣本");
            m_currentMode = RECORD_MODE;
            break;
        case 1:
            NSLog(@"練習");
            m_currentMode = PRACTICE_MODE;
            break;
        default:
            NSLog(@"Something Error");
            break;
    }
}

// 音頻比對
- (void)frequencyComparison:(NSMutableArray *)pitchLists with:(NSMutableArray *)samplePitchLists
{
    // 實驗組
    NSMutableArray* treatmentlGroup = [self removeZeroDataFromHeadAndFoot: pitchLists];
    // 對照組
    NSMutableArray* controlGroup    = [self removeZeroDataFromHeadAndFoot: samplePitchLists];

    float score = 0.0f;
    int count = 0;
    for(NSUInteger i=0; i<[controlGroup count]; i++) {
     
        float control = [[controlGroup objectAtIndex:i] floatValue];
        
        float treatmentl = 0.0f;
        if( i < [treatmentlGroup count] ) {

            treatmentl = [[treatmentlGroup objectAtIndex:i] floatValue];
        }

        float diff = fabsf( control - treatmentl );
        NSLog(@"diff(%f) = control(%f) - treatmentl(%f)", diff, control, treatmentl);
        
        if( control > 0.0f ) {

            if( diff <= 0 )         {   score += 100.0f;    }
            else if( diff <= 1 )    {   score += 90.0f;     }
            else if( diff <= 2 )    {   score += 80.0f;     }
            else if( diff <= 3 )    {   score += 75.0f;     }
            else if( diff <= 4 )    {   score += 70.0f;     }
            else if( diff <= 5 )    {   score += 65.0f;     }
            else if( diff <= 6 )    {   score += 60.0f;     }
                       
            count++;
        }
    }
    
    float avg = score / count;
    //NSLog(@"avg(%f) = score(%f) / count(%d)", avg, score, count);

    [m_scoreText setText:[NSString stringWithFormat:@"%f", avg]];
}

-(NSMutableArray *)removeZeroDataFromHeadAndFoot:(NSMutableArray *)list
{
    NSRange r;
    r.location = 0;
    r.length = 0;
    // 移除開頭無聲的部分
    for(NSUInteger i=0; i<[list count]; i++) {
        
        float f = [[list objectAtIndex:i] floatValue];
        if( f > 0.0f ) {
            
            r.length = i;
            break;
        }
    }
    [list removeObjectsInRange:r];
    //NSLog(@"list(%@)", list);

    r.location = 0;
    r.length = 0;
    // 移除結尾無聲的部分
    for(NSUInteger i=[list count]; i>0; i--) {
        
        float f = [[list objectAtIndex:i-1] floatValue];
        if( f > 0.0f ) {
            
            r.location = i;
            break;
        }
    }
    r.length = [list count] - r.location;
    [list removeObjectsInRange:r];
    //NSLog(@"list(%@)", list);
    
    return list;
}

// 準備長條圖
- (void) initBarChart:(NSMutableArray *)pitchLists with:(NSMutableArray *)samplePitchLists
{
    // 實驗組
    NSMutableArray* treatmentlGroup = [self removeZeroDataFromHeadAndFoot: pitchLists];
    // 對照組
    NSMutableArray* controlGroup    = [self removeZeroDataFromHeadAndFoot: samplePitchLists];
    
    // 長條圖陣列
    NSMutableDictionary *values = [[[NSMutableDictionary alloc] init] autorelease];
    NSMutableDictionary *values2 = [[[NSMutableDictionary alloc] init] autorelease];

    for(NSUInteger i=0; i<[controlGroup count]; i++) {

        int control = [[controlGroup objectAtIndex:i] intValue];
        int treatmentl = 0;
        if( i < [treatmentlGroup count] ) {

            treatmentl = [[treatmentlGroup objectAtIndex:i] intValue];
        }

        // 對照組
        [values setValue:[NSString stringWithFormat:@"%d", control] forKey:[NSString stringWithFormat:@"%d", i]];

        // 實驗組
        [values2 setValue:[NSString stringWithFormat:@"%d", treatmentl] forKey:[NSString stringWithFormat:@"%d", i]];
    }

    if( [values count] > 0 ) {

        barChart = [[BarChart alloc] initWithFrame:CGRectMake(0, 40, 320, 180) values:values values2:values2];

        barChart.barColor  = [UIColor colorWithRed:176.0/255.0
                                             green:212.0/255.0
                                              blue:131.0/255.0
                                             alpha:1];
        
        barChart.barColor2  = [UIColor colorWithRed:255.0/255.0
                                              green:106.0/255.0
                                               blue:106.0/255.0
                                              alpha:1];
        
        barChart.layer.zPosition = 100;
        [self.view addSubview:barChart];
        
        [barChart update];
    }
}

- (IBAction)playSampleAudio:(id)sender
{
    [self playSampleRecordedAudio];
}

- (IBAction)playVoiceSampleAudio:(id)sender
{
    [self playVoiceSampleRecordedAudio];
}

@end
