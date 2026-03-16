#include<reg52.h> //包含头文件，一般情况不需要改动，头文件包含特殊功能寄存器的定义
#include<intrins.h>
#define uint unsigned int 
#define uchar unsigned char

sbit KeyStart=P3^3;		//播放暂停
sbit KeyAddSound=P3^4;	 //声音+
sbit KeyMulSound=P3^5;	 //声音-
sbit KeyNext=P3^6;		 //下一首
sbit KeyPre=P3^7;		 //上一首

/*------------------------------------------------
 			以下是LCD102初始化程序
------------------------------------------------*/
sbit RS = P1^3;   //LCD定义端口 
sbit RW = P1^4;
sbit EN = P1^5;

#define RS_CLR RS=0 
#define RS_SET RS=1
#define RW_CLR RW=0 
#define RW_SET RW=1 
#define EN_CLR EN=0
#define EN_SET EN=1
#define DataPort P0

/*------------------------------------------------
 uS延时函数， 
------------------------------------------------*/
void DelayUs2x(unsigned char t)
{   
 while(--t);
}
/*------------------------------------------------
 mS延时函数，
------------------------------------------------*/
void DelayMs(unsigned int t)
{
     
 while(t--)
 {
     //大致延时1mS
     DelayUs2x(245);
	 DelayUs2x(245);
 }
}
/*------------------------------------------------
              判忙函数
------------------------------------------------*/
 bit LCD_Check_Busy(void) 
 { 
 DataPort= 0xFF; 
 RS_CLR; 
 RW_SET; 
 EN_CLR; 
 _nop_(); 
 EN_SET;
 return (bit)(DataPort & 0x80);
 }
/*------------------------------------------------
              写入命令函数
------------------------------------------------*/
 void LCD_Write_Com(unsigned char com) 
 {  
 while(LCD_Check_Busy()); //忙则等待
 RS_CLR; 
 RW_CLR; 
 EN_SET; 
 DataPort= com; 
 _nop_(); 
 EN_CLR;
 }
/*------------------------------------------------
              写入数据函数
------------------------------------------------*/
 void LCD_Write_Data(unsigned char Data) 
 { 
 while(LCD_Check_Busy()); //忙则等待
 RS_SET; 
 RW_CLR; 
 EN_SET; 
 DataPort= Data; 
 _nop_();
 EN_CLR;
 }

/*------------------------------------------------
                清屏函数
------------------------------------------------*/
 void LCD_Clear(void) 
 { 
 LCD_Write_Com(0x01); 
 DelayMs(5);
 }
/*------------------------------------------------
              写入字符串函数
------------------------------------------------*/
 void LCD_Write_String(unsigned char x,unsigned char y,unsigned char *s) 
 {     
 if (y == 0) 
 	{     
	 LCD_Write_Com(0x80 + x);     //表示第一行
 	}
 else 
 	{      
 	LCD_Write_Com(0xC0 + x);      //表示第二行
 	}        
 while (*s) 
 	{     
 LCD_Write_Data( *s);     
 s ++;     
 	}
 }
/*------------------------------------------------
              写入字符函数
------------------------------------------------*/
 void LCD_Write_Char(unsigned char x,unsigned char y,unsigned char Data) 
 {     
 if (y == 0) 
 	{     
 	LCD_Write_Com(0x80 + x);     
 	}    
 else 
 	{     
 	LCD_Write_Com(0xC0 + x);     
 	}        
 LCD_Write_Data( Data);  
 }
/*------------------------------------------------
              初始化函数
------------------------------------------------*/
 void LCD_Init(void) 
 {
   LCD_Write_Com(0x38);    /*显示模式设置*/ 
   DelayMs(5); 
   LCD_Write_Com(0x38); 
   DelayMs(5); 
   LCD_Write_Com(0x38); 
   DelayMs(5); 
   LCD_Write_Com(0x38);  
   LCD_Write_Com(0x08);    /*显示关闭*/ 
   LCD_Write_Com(0x01);    /*显示清屏*/ 
   LCD_Write_Com(0x06);    /*显示光标移动设置*/ 
   DelayMs(5); 
   LCD_Write_Com(0x0C);    /*显示开及光标设置*/
   }
/*------------------------------------------------
 			LCD初始化程序 结束
------------------------------------------------*/

/*------------------------------------------------
 		   UART 初始化
------------------------------------------------*/
void UART_init(void)
{
    SCON = 0x50;        // 10位uart，允许串行接受
	PCON=0x00;
    TMOD = 0x20;        // 定时器1工作在方式2（自动重装）
    TH1 = 0xFD;
    TL1 = 0xFD;
    TR1 = 1;
	EA=1;
	ES=1;
}
/*------------------------------------------------
 		   UART 发送一字节
------------------------------------------------*/
void Uart1Data(char dat)
{
	SBUF = dat;
	while (TI == 0);
	TI = 0;
}
/*------------------------------------------------
 		   UART 发送字符串
------------------------------------------------*/
void UART_send_string(char *buf)
{
	while (*buf != '\0')
	{
		Uart1Data(*buf++);
	}
}
/*------------------------------------------------
 		   UART初始化结束
------------------------------------------------*/


//
void NextMusic()	       //下一曲
 {		
 	Uart1Data(0x7e);
 	Uart1Data(0xff);
 	Uart1Data(0x06);
 	Uart1Data(0x01);
 	Uart1Data(0x00);
 	Uart1Data(0x00);
 	Uart1Data(0x00);
	Uart1Data(0xef);	 
 }

//
void PreMusic()  //上一曲
 {		
 	Uart1Data(0x7e);
 	Uart1Data(0xff);
 	Uart1Data(0x06);
 	Uart1Data(0x02);
 	Uart1Data(0x00);
 	Uart1Data(0x00);
 	Uart1Data(0x00);
	Uart1Data(0xef);	
 }
//
void Sound(int num)		//音量指定
 {		
 	Uart1Data(0x7e);
 	Uart1Data(0xff);
 	Uart1Data(0x06);
 	Uart1Data(0x06);
 	Uart1Data(0x00);
 	Uart1Data(0x00);
 	Uart1Data(num);
	Uart1Data(0xef);	
 }
//
void Start()	   //播放
 {		
 	Uart1Data(0x7e);
 	Uart1Data(0xff);
 	Uart1Data(0x06);
 	Uart1Data(0x0D);
 	Uart1Data(0x00);
 	Uart1Data(0x00);
 	Uart1Data(0x00);
	Uart1Data(0xef);	
 }
//
void Stop()	   //停止
 {		
 	Uart1Data(0x7e);
 	Uart1Data(0xff);
 	Uart1Data(0x06);
 	Uart1Data(0x0E);
 	Uart1Data(0x00);
 	Uart1Data(0x00);
 	Uart1Data(0x00);
	Uart1Data(0xef);	
 }



int soundnum=20,musicnum=1,runflag=0;//声音强度，音乐编号，运行状态 
char clr;
void main(void)    //主函数
{ 
	UART_init();  //串口初始化
   
	LCD_Init();   //显示器初始化
	LCD_Clear();//清屏
	LCD_Write_String(0,0,"MP3 PLAYER  V:  ");  //第一行显示 
	LCD_Write_String(0,1,"Music NO.    [N]");  //第二行显示	 
    DelayMs(500);
	Sound(20); //声音初始化20   0~30
	DelayMs(500);
	Sound(20); //声音初始化20   0~30
	while(1)
	{
							    

		 
	  	if(KeyPre==0)//按键上一曲
		{
			DelayMs(10);
			while(KeyPre==0); //等待松手
			if(musicnum==1);//数值最小1，
			else 
			{
				PreMusic();//发送指令
				musicnum--;//曲目-1 
				runflag=1;
			}									   
			
		}else if(KeyNext==0)//按键下一曲
		{
			DelayMs(10);
			while(KeyNext==0);//等待松手
			
			NextMusic();//发送指令
			musicnum++;//曲目+1
			runflag=1;							  
		}else if(KeyStart==0)//按键停止 播放
		{
			DelayMs(10);
			while(KeyStart==0);//等待松手
			if(runflag==0)//判断当前是播放还是暂停模式
			{		  
				Start(); //启动
				runflag=1;    
			}else
			{
				Stop();	//停止
				runflag=0; 
			}
		}


		if(KeyAddSound==0)//按键音量+
		{
			DelayMs(10);
			while(KeyAddSound==0); //等待松手
			if(soundnum<30) soundnum++; 									   
			Sound(soundnum); //声音 调节
		}else if(KeyMulSound==0)//按键音量-
		{
			DelayMs(10);
			while(KeyMulSound==0);//等待松手
			if(soundnum>1) soundnum--; 	
			Sound(soundnum); //声音 调节		   							  
		}


		LCD_Write_Char(14,0,soundnum/10+'0');	//显示声音
		LCD_Write_Char(15,0,soundnum%10+'0');

		LCD_Write_Char(9,1,musicnum/100+'0');	//显示曲目
		LCD_Write_Char(10,1,musicnum%100/10+'0');
		LCD_Write_Char(11,1,musicnum%10+'0');	 
		
		if(runflag==0) 	 LCD_Write_Char(14,1,'N');	//播放状态
		else	LCD_Write_Char(14,1,'P');
		DelayMs(100);
		 
	} 	 

} 
															  

//串行中断服务函数
void serial() interrupt 4
{
	ES=0;	//关串口中断
	clr=SBUF;	//取字节
	if(RI)
	{
		RI=0;   
	}	   
	ES=1;//串口中断
}
