/*
1.项目名称：绿深旗舰店180度舵机STC89C52测试程序
2.显示模块：串口返回数据,波特率9600
3.使用软件：keil4 for 51或keil5 for 51
4.配套上位机：无
5.项目组成：180度舵机模块
6.项目功能：按键调节转动角度，串口返回舵机转动角度数据
7.主要原理：具体参考SG90舵机数据手册
8.购买地址：https://lssz.tmall.com 或淘宝上搜索“绿深旗舰店”
10.版权声明：绿深旗舰店所有程序都申请软件著作权。均与本店产品配套出售，请不要传播，以免追究其法律责任！
接线定义:(此例程使用的晶振为11.0592M,下载程序时不要接舵机，否则可能会无法下载程序)
	舵机：
		VCC--5V
		GND--GND
		信号线--P1.0
	按键：
		加--P0.1
		减--P0.3
*/
#include "main.h"
#include "stdio.h"
#include "delay.h"
#include "Key.h"
#include "stdio.h"

u16 count;      //次数标识
u16 angle=5;         //角度标识
sbit pwm =P1^0 ;          //PWM信号输出


void Timer0_Init(void)		//100微秒@11.0592MHz
{
	TMOD |= 0x01;		//设置定时器模式
	TL0 = 0xA4;		//设置定时初值
	TH0 = 0xFF;		//设置定时初值
	TF0 = 0;		//清除TF0标志
	TR0 = 1;		//定时器0开始计时
	ET0 = 1;
}


void Uart_Init(void)		//9600bps@11.0592MHz
{
	SCON = 0x50;		//8位数据,可变波特率
	TMOD |= 0x20;		//设定定时器1为8位自动重装方式
	TL1 = 0xFD;		//设定定时初值
	TH1 = 0xFD;		//设定定时器重装值
	ET1 = 0;		//禁止定时器1中断
	TR1 = 1;		//启动定时器1
	ES = 1;
	EA = 1;
}

void Uart_SendData(u8 dat )
{
	SBUF = dat;
	while(TI == 0);
	TI = 0;
}

void Uart_SendString(char *s)
{
	while (*s)              
	{
		Uart_SendData(*s++);
	}
}


void main(void)
{
	//angle与对应角度关系
	//4   5   6   ...... 19  20
	//0   11  22  ...... 166 177
	u8 str[5];
	Uart_Init();
	Timer0_Init();
	Uart_SendString("舵机正在做往复运动。\r\n");
	for(angle=4;angle<21;angle++)//从0到177度，步进11度
	{
		delay_ms(200);
	}
	for(angle=20;angle>4;angle--)//从177到0度，步进11度
	{
		delay_ms(200);
	}
	Uart_SendString("完成往复运动，可通过按键调节角度。\r\n");
	while(1)
	{             
		key_num=KEY_Scan(0);
		if(key_num==1)
		{
			angle++;
			if(angle>=21)
				angle=20;
			sprintf(str,"%d",(int)((angle-4)*11.11));//将angle值转化为具体的角度值
			Uart_SendString("角度:");//发送角度数据
			Uart_SendString(str);
			Uart_SendString("°\r\n");
		}
		else if(key_num==2)
		{
			angle--;
			if(angle==3)
				angle=4;
			sprintf(str,"%d",(int)((angle-4)*11.11));
			Uart_SendString("角度:");
			Uart_SendString(str);
			Uart_SendString("°\r\n");
		}
	}
}

void Uart_Isr() interrupt 4
{
    if (RI)
    {
        RI = 0;  
	}
}


void Timer0_Isr() interrupt 1
{
	TL0 = 0xA4;		//设置定时初值
	TH0 = 0xFF;		//设置定时初值
	if(count< angle)              //判断次数是否小于角度标识
      pwm=1;                  //确实小于，PWM输出高电平
    else
      pwm=0;                  //大于则输出低电平
    count=(count+1);          //0.1ms次数加1
    count=count%160;     //保持周期为20ms，普通51单片机定时100us有误差，经示波器测量约为50Hz
}
