#ifndef __KEY_H
#define __KEY_H

#include "Delay.h"

#define uchar unsigned char 
#define uint unsigned int

//定义按键输入端口
sbit KEY1=P0^1;
sbit KEY2=P0^3;


extern uchar key_num;

//按键处理函数
//返回按键值
//mode:0,不支持连续按;1,支持连续按;

uchar KEY_Scan(uchar mode);




#endif
