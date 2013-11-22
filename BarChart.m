#import "BarChart.h"

@implementation BarChart

-(id)initWithFrame:(CGRect)frame values:(NSMutableDictionary *)aValues values2:(NSMutableDictionary *)aValues2
{
    self = [super initWithFrame:frame];
    if (self) {

        self.backgroundColor = [UIColor clearColor];

        values  = [[NSMutableDictionary alloc] initWithDictionary:aValues];
        values2 = [[NSMutableDictionary alloc] initWithDictionary:aValues2];
        
        m_height   = self.frame.size.height;
        m_width    = self.frame.size.width;

        NSArray * allKeys = [values allKeys];
        m_barWidth = m_width / [allKeys count];
        m_barHeight = 3;
        m_min = 0;
        m_max = 100;
    }

    return self;
}

- (void)drawRect:(CGRect)rect
{
    int maxFrequency = 50;
    int lowFrequency = 0;
    
    // 清除畫面
    UIColor *bgColor = [UIColor colorWithRed:0.0/255.0
                                       green:0.0/255.0
                                        blue:0.0/255.0
                                       alpha:1];
    CGRect bgRect = CGRectMake(0,
                               0,
                               m_width,
                               m_height);
    [bgColor setFill];
    UIRectFill(bgRect);

    [self.barColor setFill];
    [self.barColor setStroke];

    UIColor *lineColor = [UIColor colorWithRed:255.0/255.0
                                         green:255.0/255.0
                                          blue:255.0/255.0
                                         alpha:1];

    // x軸底線
    CGRect xLineRect = CGRectMake(0,
                            m_height - 5,
                            m_width,
                            5);
    [lineColor setFill];
    UIRectFill(xLineRect);

    // y軸底線
    CGRect yLineRect = CGRectMake(0,
                            0,
                            5,
                            m_height);
    [lineColor setFill];
    UIRectFill(yLineRect);

    NSArray * allKeys = [values allKeys];
    int count = [allKeys count];

    NSArray * allKeys2 = [values2 allKeys];
    int count2 = [allKeys2 count];

    for(int i=0; i<count; i++) {

        NSString *key = [NSString stringWithFormat:@"%d", i];
        float value =  [[values valueForKey:key] floatValue];

        float value2 = 0.0f;
        if( i < count2 ) {

            value2 =  [[values2 valueForKey:key] floatValue];
        }

        // 對照組
        float barHeight = ( value - lowFrequency ) / ( maxFrequency - lowFrequency ) * m_height;
        //NSLog(@"value(%f) barHeight(%f)", value, barHeight);
        CGRect bar = CGRectMake(m_barWidth * i,
                                m_height - barHeight,
                                m_barWidth,
                                m_barHeight);
        
        [self.barColor setFill];
        UIRectFill(bar);

        // 實驗組
        float barHeight2 = ( value2 - lowFrequency ) / ( maxFrequency - lowFrequency ) * m_height;
        //NSLog(@"value2(%f) barHeight2(%f)", value, barHeight);
        CGRect bar2 = CGRectMake(m_barWidth * i,
                                 m_height - barHeight2,
                                 m_barWidth,
                                 m_barHeight);

        [self.barColor2 setFill];
        UIRectFill(bar2);
    }
}

- (void)update
{
    [self setNeedsDisplay];
}
@end
