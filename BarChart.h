#import <UIKit/UIKit.h>

@interface BarChart : UIView
{
    // 對照組
    NSMutableDictionary *values;

    // 實驗組
    NSMutableDictionary *values2;

    float m_min;
    float m_max;
    float m_width;
    float m_height;
    float m_barWidth;
    float m_barHeight;

    int m_currentTick;
}

@property(nonatomic,strong)UIColor *barColor;
@property(nonatomic,strong)UIColor *barColor2;

-(id)initWithFrame:(CGRect)frame values:(NSMutableDictionary *)aValues values2:(NSMutableDictionary *)aValues2;
- (void)update;

@end
