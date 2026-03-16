#include "Delay.h"
#include "Key.h"

uchar key_num;

//按键处理函数
//返回按键值
//mode:0,不支持连续按;1,支持连续按;

uchar KEY_Scan(uchar mode)
{	 
	static uchar key_up=1;//按键按松开标志
	if(mode)key_up=1;  //支持连按		  
	if(key_up&&(KEY1==0||KEY2==0))
	{
		delay_ms(10);//去抖动 
		key_up=0;
		if(KEY1==0)return 1;
		else if(KEY2==0)return 2;
	}else if(KEY1==1&&KEY2==1)key_up=1; 	    
 	return 0;// 无按键按下
}

