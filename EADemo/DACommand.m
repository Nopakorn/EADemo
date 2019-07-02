//
//  DACommand.m
//  EADASample
//
//  Created by Nonthawatt P on 31/5/2562 BE.
//  Copyright © 2562 OTR. All rights reserved.
//

#import "DACommand.h"
#import "EADSessionController.h"

// メッセージ共通部分
#define COMMAND_DUMMY                  ( 0x11 )
#define COMMAND_STARTBIT               ( 0x7E )
#define COMMAND_STOPBIT                ( 0x7E )

//send
#define COMMAND_NOTIFY_TIME_RES        ( 0x10 ) // Add New
#define COMMAND_NOTIFYCONNECT          ( 0x31 )
#define COMMAND_CARINFOREQ             ( 0x30 )
#define COMMAND_TRIPINFOREQUEST        ( 0x32 )
#define COMMAND_NOTIFY_APP_INFO        ( 0x34 ) // Add New
#define COMMAND_NOTIFY_VEHICLE_INFO    ( 0x35 ) // Add New
#define COMMAND_TRIPINFO_SEND          ( 0x54 )
#define COMMAND_BATTERYINFO            ( 0x51 )
#define COMMAND_CLIENTSTARTRES         ( 0x52 )
#define COMMAND_DESITINATIONREQ        ( 0x70 )
#define COMMAND_TRANSFERDESTINATION    ( 0x71 )
#define COMMAND_DESITINATION           ( 0x55 )
#define COMMAND_ARRIVERES              ( 0x56 )
#define COMMAND_REGISTRATIONREQ        ( 0x72 )
#define COMMAND_AROUNDFACILITIES       ( 0x73 )
#define COMMAND_RANDOMNUMNOTIFY        ( 0x74 )
#define COMMAND_HMACINFORES            ( 0x53 )
#define COMMAND_CLIENTEDNOTIFY         ( 0x33 )
#define COMMAND_HANDSFREE              ( 0x91 )
#define COMMAND_TRIPINFO_UPLOADRESULT  ( 0x57 ) // Add New

//receive
#define COMMAND_NOTIFYREQ_TIME         ( 0x00 ) // Add New
#define COMMAND_NOTIFYCONNECTRES       ( 0x21 )
#define COMMAND_CARINFORES             ( 0x20 )
#define COMMAND_TRIPINFO_RECEIVE       ( 0x22 )
#define COMMAND_APP_INFO_RES           ( 0x24 ) // Add New
#define COMMAND_VEHICLE_INFO_RES       ( 0x25 ) // Add New
#define COMMAND_TRIPINFONOTIFY         ( 0x44 )
#define COMMAND_CARINFOPERIODIC        ( 0x40 )
#define COMMAND_BATTERYINFORES         ( 0x41 )
#define COMMAND_CLIENTAUTHSTART        ( 0x42 )
#define COMMAND_DESITINATIONRES        ( 0x60 )
#define COMMAND_TRANSFERDESTINATIONRES ( 0x61 )
#define COMMAND_DESTINATION_SETTING    ( 0x45 )
#define COMMAND_ARRIVENOTIFY           ( 0x46 )
#define COMMAND_REGISTRATION           ( 0x62 )
#define COMMAND_SURROUNDING            ( 0x63 )
#define COMMAND_SERVERRANDOMNUMRES     ( 0x64 )
#define COMMAND_HMACRES                ( 0x43 )
#define COMMAND_CLIENTAUTHEND          ( 0x23 )
#define COMMAND_RECIEVE_HANDSFREE      ( 0x81 )

// App種別
#define COMMAND_APP_TYPE_IOS           ( 0x00 )
#define COMMAND_APP_TYPE_ANDROID       ( 0x01 )
#define COMMAND_APP_TYPE_OTHER         ( 0x02 )

// BEEP用
#define COMMAND_BEEP                   ( 0x00 )



@implementation DACommand
@synthesize eCode;

/**
 * @brief 取得シーケンス番号を16進数に変換
 * @param 取得データ
 */
-(NSData *)convertSeqNoToHEX:(int)seq
{
    uint8_t byte[2];
    byte[0] = (seq >> 8);
    byte[1] = (seq & 0xFF);
    
    return [NSData dataWithBytes:byte length:2];
}

#pragma mark -------------------------------------
#pragma mark DAへのデータ送信
// 初期化
- (id)init
{
    if(self = [super init]){
        /* initialization code */
        
        // トランザクションID初期化
        [self initTransactionID];
        seqNo = 0;
        connectCnt = 0;
        eCode = @"";
    }
    return self;
}

// 送信処理
-(NSData*)daSendMessage:(NSData *)getData {
    NSMutableData* data = [[NSMutableData alloc] initWithLength:0];
    uint8_t byte[1];
    
    NSLog(@"送信する内部データ:%@",getData);
    
    //スタートビット
    byte[0] = COMMAND_STARTBIT;
    [data appendBytes:byte length:1];
    // 長さ
    int length = [getData length];
    [data appendData:[self convertSeqNoToHEX:length]];
    
    // 送られてきたデータ
    [data appendData:getData];
    
    // チェックサム
    [data appendData:[self checkSum:length byte:getData]];
    
    
    //ストップビット
    byte[0] = COMMAND_STOPBIT;
    [data appendBytes:byte length:1];
    
    NSLog(@"DAに送信します。data:%@",data);
    return data;
}

-(NSData*)checkSum:(int)datalen byte:(NSData*) commandCls {
    
    NSMutableData* data = [[NSMutableData alloc] initWithLength:0];
    NSData* len = [self convertSeqNoToHEX:datalen];
    [data appendData:len];
    [data appendData:commandCls];
    
    const unsigned char* bytes = [data bytes];
    uint8_t sum1 = 0x00;
    uint8_t sum2 = 0x00;
    for (int i = 0; i < data.length; i = i + 2) {
        sum1 = (sum1 ^ (uint8_t)bytes[i]);
        sum2 = (sum2 ^ (uint8_t)bytes[i+1]);
    }
    uint8_t byte[2];
    byte[0] = sum1;
    byte[1] = sum2;
    
    NSMutableData* checkSumd = [[NSMutableData alloc] initWithLength:0];
    [checkSumd appendBytes:byte length:2];
    
    return checkSumd;
    
}

#pragma mark -------------------------------------
#pragma mark DAへの応答電文作成処理
-(void)initSpToDa{
    NSLog(@"送信データの削除");
    if (spToDaData) {
        //[spToDaData release];
        spToDaData = nil;
    }
}

-(void)initCount{
    NSLog(@"リトライ回数の初期化");
    connectCnt = 0;
}


/**
 * @brief 取得シーケンス番号を10進数に変換
 * @param 取得データ
 */
-(int)convertSeqNoToDEX:(NSData *)data
{
    //1~2桁を数値に変換
    const unsigned char* bytes = [data bytes];
    unsigned int int1 = (unsigned int)bytes[7];
    unsigned int int2 = (unsigned int)bytes[8];
    
    unsigned int conSeqNo = ( int1 << 8 ) | int2;
    return conSeqNo;
}


/**
 * @brief 現在時刻取得応答(10H)
 */
-(NSData*)sendRequestTime: (NSData *)getData  {
    
    NSMutableData* data = [[NSMutableData alloc] initWithLength:0];
    uint8_t byte[1];
    // CMDType
    byte[0] = COMMAND_NOTIFY_TIME_RES;
    [data appendBytes:byte length:1];
    
    //seqNo
//    uint8_t byte2[2];
//    byte2[0] = 0x80;
//    byte2[1] = 0x09;
//    [data appendBytes:byte2 length:2];
    [data appendData:[getData subdataWithRange:NSMakeRange(5, 4)]];
    
    // 時刻情報長 - Time info length
    uint8_t timeInfoByte[2];
    timeInfoByte[0] = 0x00;
    timeInfoByte[1] = 0x07;
    [data appendBytes:timeInfoByte length:2];
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *dateComponents = [calendar components:( NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour  | NSCalendarUnitMinute | NSCalendarUnitSecond) fromDate:[NSDate date]];
    NSInteger year = [dateComponents year];
    NSInteger month = [dateComponents month];
    NSInteger day = [dateComponents day];
    NSInteger hour = [dateComponents hour];
    NSInteger minute = [dateComponents minute];
    NSInteger second = [dateComponents second];
    
    uint8_t dateTimeByte[7];
    // year
    dateTimeByte[0] = ( year >> 8) & 0xFF;
    dateTimeByte[1] = ( year >> 0) & 0xFF;
    // month
    dateTimeByte[2] = month;
    // day
    dateTimeByte[3] = day;
    // hour
    dateTimeByte[4] = hour;
    // min
    dateTimeByte[5] = minute;
    // sec
    dateTimeByte[6] = second;
    // 時刻情報 - Time info
    [data appendBytes:dateTimeByte length:7];
    
    NSLog(@"現在時刻取得応答(10H)");
    NSLog(@"作成data : %@",data);
    
    return [self daSendMessage:data];
}

/**
 * @brief T/Cアプリ情報通知(34H)
 */// MARK: 34H
- (NSData *)sendAppInfo:(NSData*) getData {
    NSInteger getDatas = 0;
    NSMutableData* data = [[NSMutableData alloc] initWithLength:0];
    uint8_t byte[1];
    // CMDType
    byte[0] = COMMAND_NOTIFY_APP_INFO;
    [data appendBytes:byte length:1];
    // seqNo
    //[data appendData:[getData subdataWithRange:NSMakeRange(4, 2)]];
    [data appendData:[self convertSeqNoToHEX:[self getAndIncrementTransactionID]]];
    
    // Country Name 32 byte
    NSString *country = @"THA";
    NSData *datacountry = [country dataUsingEncoding:NSASCIIStringEncoding];
    [data appendData: datacountry];
    unsigned long datacountryLength = 32 - [datacountry length];
    if(datacountryLength > 0) {
        NSMutableData* emptyData = [[NSMutableData alloc] initWithLength:datacountryLength];
        [data appendData:emptyData];
    }
    //    uint8_t countryByte[32];
    //    [data appendBytes:countryByte length:32];
    // App種別
    byte[0] = COMMAND_APP_TYPE_IOS;
    [data appendBytes:byte length:1];
    // Bundle name
    // NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    NSString *bundleIdentifier = @"th.co.dmap.smgb.th.1232";
    NSData *newData = [bundleIdentifier dataUsingEncoding:NSASCIIStringEncoding];
    [data appendData:newData];
    // Protocol文字列 (Protocol iap Authentication) (com.g-book.tsc.tconnect.eda)
    unsigned long emptyLength = 64 - [newData length];
    if(emptyLength > 0) {
        NSMutableData* emptyData = [[NSMutableData alloc] initWithLength:emptyLength];
        [data appendData:emptyData];
    }
    
    // Protocol文字列 (Protocol iap Authentication) (com.g-book.tsc.tconnect.eda)
    NSString *protocolIAP = @"com.g-book.tsc.tconnect.eda";
    NSData *protocolData = [protocolIAP dataUsingEncoding:NSASCIIStringEncoding];
    [data appendData:protocolData];
    emptyLength = 64 - [protocolData length];
    if(emptyLength > 0) {
        NSMutableData* emptyData = [[NSMutableData alloc] initWithLength:emptyLength];
        [data appendData:emptyData];
    }
    //    // Android -----
    //メーカー名称 (Manufacturer name) (Toyota Multimedia)
    // todo - add manufacture byte
    NSMutableData* menuFacBytes = [[NSMutableData alloc] initWithLength:64];
    [data appendData:menuFacBytes];
    //モデル名称 (Model name) (TOYOTA)
    // todo - add model name byte
    NSMutableData* modelNameBye = [[NSMutableData alloc] initWithLength:64];
    [data appendData:modelNameBye];
    //バージョン (Version) (3.0.0.2.43)
    // todo - add version byte
    NSMutableData* versionByte = [[NSMutableData alloc] initWithLength:16];
    [data appendData:versionByte];
    
    NSLog(@"T/Cアプリ情報通知(34H)");
    NSLog(@"作成data : %@",data);
    //    [self printlog:data];
    /// Uncomment to send message to device
    return [self daSendMessage:data];
}

/**
 * @bref 車両情報機能設定通知(35H)
 */// MARK: 35H
-(NSData*)sendVehicleInfo:(NSData*) getData {
    NSMutableData* data = [[NSMutableData alloc] initWithLength:0];
    uint8_t byte[1];
    // CMDType
    byte[0] = COMMAND_NOTIFY_VEHICLE_INFO;
    [data appendBytes:byte length:1];
    // seqNo
    [data appendData:[getData subdataWithRange:NSMakeRange(5, 2)]];
    // CANデータ蓄積に関する機能(CAN data storage) -> ON:0x00, OFF:0x01
    byte[0] = 0x00;
    [data appendBytes:byte length:1];
    // 車両情報の送信に関する機能(Vehicle Info) -> ON:0x00, OFF:0x01
    byte[0] = 0x00;
    [data appendBytes:byte length:1];
    
    // dummy
    byte[0] = COMMAND_DUMMY;
    [data appendBytes:byte length:1];
    
    NSLog(@"車両情報機能設定通知(35H)");
    NSLog(@"作成data : %@",data);
    //    [self printlog:data];
    /// Uncomment to send message to device
    return [self daSendMessage:data];
}

/**
 * @brief Trip情報確認コマンドを送信(54H)
 */
-(NSData*)sendTripInfo:(NSData*)getData
{
    NSMutableData* data = [[NSMutableData alloc] initWithLength:0];
    uint8_t byte[1];
    // CMDType
    byte[0] = COMMAND_TRIPINFO_SEND;
    [data appendBytes:byte length:1];
    
    //seqNo
    [data appendData:[getData subdataWithRange:NSMakeRange(5, 2)]];
    
    // dummy
    byte[0] = COMMAND_DUMMY;
    [data appendBytes:byte length:1];
    
    //DAへデータを送信する
    NSLog(@"Trip情報確認メッセージ送信(54H)");
    NSLog(@"作成data : %@",data);
    //    [self printlog:data];
    return [self daSendMessage:data];
}

/**
 * @brief クライアント認証開始確認
 */
-(NSData*)sendClientStart:(NSData*)getData
{
    NSMutableData* data = [[NSMutableData alloc] initWithLength:0];
    uint8_t byte[1];
    //CMDType
    byte[0] = COMMAND_CLIENTSTARTRES;
    [data appendBytes:byte length:1];
    
    //seqNo
    [data appendData:[getData subdataWithRange:NSMakeRange(5, 2)]];
    
    // dummy
    byte[0] = COMMAND_DUMMY;
    [data appendBytes:byte length:1];
    
    //DAへデータを送信する
    NSLog(@"クライアント認証開始確認メッセージ送信(52H)");
    NSLog(@"作成data : %@",data);
    //    [self printlog:data];
    return [self daSendMessage:data];
}

/**
 * @brief +Boff確認コマンドを生成
 */
-(NSData*)sendBatteryInfo:(NSData*)getData
{
    NSMutableData* data = [[NSMutableData alloc] initWithLength:0];
    uint8_t byte[1];
    //CMDType
    byte[0] = COMMAND_BATTERYINFO;
    [data appendBytes:byte length:1];
    
    //seqNo
    [data appendData:[getData subdataWithRange:NSMakeRange(5, 2)]];
    
    // dummy
    byte[0] = COMMAND_DUMMY;
    [data appendBytes:byte length:1];
    
    //DAへデータを送信する
    NSLog(@"+B off情報確認メッセージ送信(51H)");
    NSLog(@"作成data : %@",data);
    //    [self printlog:data];
    return [self daSendMessage:data];
}

/**
 * @brief HMAC確認
 */
-(NSData*)sendHMACResponse:(NSData*)getData
{
    NSMutableData* data = [[NSMutableData alloc] initWithLength:0];
    uint8_t byte[1];
    //CMDType
    byte[0] = COMMAND_HMACINFORES;
    [data appendBytes:byte length:1];
    
    //seqNo
    [data appendData:[getData subdataWithRange:NSMakeRange(5, 2)]];
    
    // dummy
    byte[0] = COMMAND_DUMMY;
    [data appendBytes:byte length:1];
    
    //DAへデータを送信する
    NSLog(@"HMAC確認メッセージ送信(53H)");
    NSLog(@"作成data : %@",data);
    //    [self printlog:data];
    return [self daSendMessage:data];
}

/**
 * @brief 目的地設定データ通知確認
 */
-(NSData*)senfDestinationSetting:(NSData*)getData
{
    NSMutableData* data = [[NSMutableData alloc] initWithLength:0];
    uint8_t byte[1];
    
    //CMDType
    byte[0] = COMMAND_DESITINATION;
    [data appendBytes:byte length:1];
    
    //seqNo
    [data appendData:[getData subdataWithRange:NSMakeRange(5, 2)]];
    
    // dummy
    byte[0] = COMMAND_DUMMY;
    [data appendBytes:byte length:1];
    
    //DAへデータを送信する
    NSLog(@"目的地設定確認メッセージ送信(55H)");
    NSLog(@"作成data : %@",data);
    //    [self printlog:data];
    return [self daSendMessage:data];
}

/**
 * @brief 目的地到着データ通知確認
 */
-(NSData*)sendArriveRes:(NSData*)getData
{
    NSMutableData* data = [[NSMutableData alloc] initWithLength:0];
    uint8_t byte[1];
    //CMDType
    byte[0] = COMMAND_ARRIVERES;
    [data appendBytes:byte length:1];
    
    //seqNo
    [data appendData:[getData subdataWithRange:NSMakeRange(5, 2)]];
    
    // dummy
    byte[0] = COMMAND_DUMMY;
    [data appendBytes:byte length:1];
    
    //DAへデータを送信する
    NSLog(@"目的地到着確認メッセージ送信(56H)");
    NSLog(@"作成data : %@",data);
    //    [self printlog:data];
    return [self daSendMessage:data];
}

/**
 * @brief Trip情報アップロード結果通知
 */
-(NSData*)sendTripInfoResult:(NSData*)getData result:(BOOL)isSuccess
{
    NSMutableData* data = [[NSMutableData alloc] initWithLength:0];
    uint8_t byte[1];
    //CMDType
    byte[0] = COMMAND_TRIPINFO_UPLOADRESULT;
    [data appendBytes:byte length:1];
    
    //seqNo
    [data appendData:[getData subdataWithRange:NSMakeRange(5, 2)]];
    
    // Update result
    byte[0] = (isSuccess) ? 0x00 : 0x01 ;  // success: 0x00, failed: 0x01
    [data appendBytes:byte length:1];
    
    //DAへデータを送信する
    NSLog(@"Trip情報アップロード結果通知(57H)");
    NSLog(@"作成data : %@",data);
    return [self daSendMessage:data];
}

#pragma mark -------------------------------------
#pragma mark DAへのデータ送信(スマホからの呼び出し)

/**
 * @brief 接続通知コマンドを生成 (31H)
 */
-(NSData*)sendNotifyConnect
{
    @synchronized(self) {
        NSMutableData* data = [[NSMutableData alloc] initWithLength:0];
        uint8_t byte[1];
        
        
        // CMDType
        byte[0] = COMMAND_NOTIFYCONNECT;
        [data appendBytes:byte length:1];
        
        // seqNo
        [data appendData:[self convertSeqNoToHEX:[self getAndIncrementTransactionID]]];
        
        
        // 車載機seqNo
        [data appendData:[self convertSeqNoToHEX:[self getDaTransactionID]]];
        
        // dummy
        byte[0] = COMMAND_DUMMY;
        [data appendBytes:byte length:1];
        
        //DAへデータを送信する
        NSLog(@"接続通知メッセージ送信(31H)");
        NSLog(@"作成data : %@",data);
        
        return [self daSendMessage:data];
    }
}



/**
 * @brief Trip情報取得要求コマンドを送信(32H)
 */
-(NSData*)sendGetTripInfo
{
    @synchronized(self) {
        NSMutableData* data = [[NSMutableData alloc] initWithLength:0];
        uint8_t byte[1];
        // CMDType
        byte[0] = COMMAND_TRIPINFOREQUEST;
        [data appendBytes:byte length:1];
        
        //seqNo
        [data appendData:[self convertSeqNoToHEX:[self getAndIncrementTransactionID]]];
        
        // dummy
        byte[0] = COMMAND_DUMMY;
        [data appendBytes:byte length:1];
        
        //DAへデータを送信する
        NSLog(@"Trip情報取得要求メッセージ送信(32H)");
        NSLog(@"作成data : %@",data);
        return [self daSendMessage:data];
    }
}

/**
 * @brief 目的地設定要求コマンドを送信(70H)
 */
-(NSData*)sendDesitinationRewuestDataWithFromParam:(NSData*)spData
{
    @synchronized(self) {
        NSMutableData* data = [[NSMutableData alloc] initWithLength:0];
        uint8_t byte[1];
        // CMDType
        byte[0] = COMMAND_DESITINATIONREQ;
        [data appendBytes:byte length:1];
        
        //seqNo
        [data appendData:[self convertSeqNoToHEX:[self getAndIncrementTransactionID]]];
        
        // スマホから送られてきた目的地情報をセット
        [data appendData:spData];
        
        //DAへデータを送信する
        NSLog(@"目的地設定要求メッセージ送信(70H)");
        NSLog(@"作成data : %@",data);
        
        return [self daSendMessage:data];
    }
}

/**
 * @brief 目的地転送要求コマンドを送信(71H)
 */
-(NSData*)sendTransferDestination
{
    @synchronized(self) {
        NSMutableData* data = [[NSMutableData alloc] initWithLength:0];
        // CMDType
        uint8_t byte[1];
        byte[0] = COMMAND_TRANSFERDESTINATION;
        [data appendBytes:byte length:1];
        
        // seqNo
        [data appendData:[self convertSeqNoToHEX:[self getAndIncrementTransactionID]]];
        
        // dummy
        byte[0] = COMMAND_DUMMY;
        [data appendBytes:byte length:1];
        
        //DAへデータを送信する
        NSLog(@"目的地転送要求メッセージ送信(71H)");
        NSLog(@"作成data : %@",data);
        
        return [self daSendMessage:data];
    }
}

/**
 * @brief 登録地設定要求コマンドを送信(72H)
 */
-(NSData*)sendRegistrationPointDataWithFromParam:(NSData*)spData
{
    @synchronized(self) {
        NSMutableData* data = [[NSMutableData alloc] initWithLength:0];
        //CMDType
        uint8_t byte[1];
        byte[0] = COMMAND_REGISTRATIONREQ;
        [data appendBytes:byte length:1];
        
        //seqNo
        [data appendData:[self convertSeqNoToHEX:[self getAndIncrementTransactionID]]];
        
        // スマホから送られてきた登録地設定情報をセット
        [data appendData:spData];
        
        //DAへデータを送信する
        NSLog(@"登録地設定要求メッセージ送信(72H)");
        NSLog(@"作成data : %@",data);
        
        return [self daSendMessage:data];
    }
}

/**
 * @brief 周辺施設設定要求コマンドを送信(73H)
 */
-(NSData*)sendAroundDataWithFromParam:(NSData*)spData
{
    @synchronized(self) {
        NSMutableData* data = [[NSMutableData alloc] initWithLength:0];
        uint8_t byte[1];
        // CMDType
        byte[0] = COMMAND_AROUNDFACILITIES;
        [data appendBytes:byte length:1];
        
        //seqNo
        [data appendData:[self convertSeqNoToHEX:[self getAndIncrementTransactionID]]];
        
        // スマホから送られてきた周辺施設情報をセット
        [data appendData:spData];
        
        //DAへデータを送信する
        NSLog(@"周辺施設設定要求メッセージ送信(73H)");
        NSLog(@"作成data : %@",data);
        
        return [self daSendMessage:data];
    }
}

/**
 * @brief サーバー乱数通知を送信(74H)
 */
-(NSData*)sendRandomNumber:(NSData*)spData
{
    @synchronized(self) {
        NSLog(@"DAPioController:送信データを作成");
        NSMutableData* data = [[NSMutableData alloc] initWithLength:0];
        uint8_t byte[1];
        //CMDType
        byte[0] = COMMAND_RANDOMNUMNOTIFY;
        [data appendBytes:byte length:1];
        
        //seqNo
        [data appendData:[self convertSeqNoToHEX:[self getAndIncrementTransactionID]]];
        
        NSLog(@"SPからの送られてきたデータ:%@",spData);
        // スマホから送られてきたサーバー乱数をセット
        [data appendData:spData];
        
        // dummy
        byte[0] = COMMAND_DUMMY;
        [data appendBytes:byte length:1];
        
        //DAへデータを送信する
        NSLog(@"サーバー乱数通知メッセージ送信(74H)");
        NSLog(@"作成data : %@",data);
        
        return [self daSendMessage:data];
    }
}
/**
 * @brief 車両情報取得要求を送信(30H)
 */
-(NSData*)sendCarInfo
{
    @synchronized(self) {
        NSLog(@"DAPioController:送信データを作成");
        NSMutableData* data = [[NSMutableData alloc] initWithLength:0];
        uint8_t byte[1];
        //CMDType
        byte[0] = COMMAND_CARINFOREQ;
        [data appendBytes:byte length:1];
        
        //seqNo
        [data appendData:[self convertSeqNoToHEX:[self getAndIncrementTransactionID]]];
        
        // dummy
        byte[0] = COMMAND_DUMMY;
        [data appendBytes:byte length:1];
        
        //DAへデータを送信する
        NSLog(@"車両情報取得要求メッセージ送信(30H)");
        NSLog(@"作成data : %@",data);
        
        return [self daSendMessage:data];
    }
}
/**
 * @brief クライアント認証完了通知を送信(33H)
 */
-(NSData*)sendClientEnd:(NSData*)spData {
    NSMutableData* data = [[NSMutableData alloc] initWithLength:0];
    uint8_t byte[1];
    //CMDType
    byte[0] = COMMAND_CLIENTEDNOTIFY;
    [data appendBytes:byte length:1];
    
    //seqNo
    [data appendData:[self convertSeqNoToHEX:[self getAndIncrementTransactionID]]];
    
    // スマホから送られてきた周辺施設情報をセット
    [data appendData:spData];
    
    //DAへデータを送信する
    NSLog(@"クライアント認証完了通知メッセージ送信(33H)");
    NSLog(@"作成data : %@",data);
    
    return [self daSendMessage:data];
    
}

// transactionIDを取得してインクリメント
- (unsigned short)getAndIncrementTransactionID
{
    if (nextPioTransactionID_ > 65535) {
        [self initTransactionID];
    }
    unsigned short current = nextPioTransactionID_;
    nextPioTransactionID_++;
    seqNo = current;
    return current;
}

// パイオニアDA用シーケンス番号取得処理
- (unsigned short)getDaTransactionID
{
    pioDaTransactionID_ = 1;
    return pioDaTransactionID_;
}

- (void)initTransactionID
{
    nextPioTransactionID_ = 1;
}


- (void)preceivedData: (NSData *)data{
//    DACarInfo *carInfo = [DACarInfo getInstance];
//    NSLog(@"DAから受信したデータ:%@",data);
    
    // シーケンスの流れを確認して処理が続くものは前の電文のチェックを
    // 処理が続かないものはチェックを行わずに応答処理を返信する
    // 応答処理に関しては、一度投げればOKとする再送信とうは気にしない
    
    // 受信したデータを保管する
    //const unsigned char * bytes = 0x0000000174039870
    const unsigned char* bytes = [data bytes];
    // コマンドを判別する
    unsigned short cmdType = bytes[6];
    
    if (cmdType != COMMAND_CARINFOPERIODIC) {
        NSLog(@"車両情報定期通知以外の時保存する");
        // 正常のデータを受信したので格納する
        //carInfo.sendData = data;
    }
    
    switch (cmdType) {
        case COMMAND_NOTIFYREQ_TIME:
            // MARK: 00H
            NSLog(@"現在時刻取得要求(00H)");
            //[self printlogReceive:data];
            /// Notify request time from DA
            NSInteger h00 = 0;
            [self getRequestTime: data];
            
            // MARK: コール機能 10H
            [[EADSessionController sharedController] writeData:[self sendRequestTime: data]];
            
            // 現在時刻取得要求、送信したデータを削除する
            [self initSpToDa];
            [self initCount];
            break;
        case COMMAND_NOTIFYCONNECTRES:
            NSLog(@"接続応答受信(21H)");
            //[self printlogReceive:data];
            // 接続応答 (SP → DA)
            if (![self checkDataMatch:COMMAND_NOTIFYCONNECT]) {
                return;
            }
            // 接続応答受信した為、送信したデータを削除する
            [self initSpToDa];
            [self initCount];
            break;
        case COMMAND_CLIENTAUTHSTART:
            NSLog(@"クライアント認証開始通知(42H)");
            //[self printlogReceive:data];
            // クライアント認証開始通知 (DA→SP)
            //            if (![self checkDataMatch:COMMAND_BATTERYINFO]) {
            //                return;
            //            }
            
            // クライアント認証開始確認呼出
            [self sendClientStart:data];
            
            // 上位に通知
            //[delegate recieveClientAuthentication:data];
            
            break;
        case COMMAND_SERVERRANDOMNUMRES:
            NSLog(@"サーバー乱数確認(64H)");
            //[self printlogReceive:data];
            // 乱数確認 (SP→DA) 初期化必要
            if (![self checkDataMatch:COMMAND_RANDOMNUMNOTIFY]) {
                return;
            }
            NSLog(@"サーバー乱数チェック処理終了");
            // サーバー乱数通知応答を受信した為、送信したデータを削除する
            [self initSpToDa];
            [self initCount];
            // 上位に通知
            //[delegate recieveRandomNumber:data];
            break;
        case COMMAND_HMACRES:
            NSLog(@"HMAC通知(43H)");
            //[self printlogReceive:data];
            // HMAC通知(43H) (DA→SP)
            //            if (![self checkDataMatch:COMMAND_SERVERRANDOMNUMRES]) {
            //                return;
            //            }
            //HMAC確認
            [self sendHMACResponse:data];
            // 上位に通知
            //[delegate recieveHmacInfo:data];
            break;
        case COMMAND_CLIENTAUTHEND:
            NSLog(@"クライアント認証完了通知(23H)");
            //[self printlogReceive:data];
            // クライアント認証完了取得 (SP→DA) 初期化必要
            if (![self checkDataMatch:COMMAND_CLIENTEDNOTIFY]) {
                return;
            }
            
            // TODO: コール機能 34H
            [self sendAppInfo:data];
            
            // クライアント認証完了取得受信した為、送信したデータを削除する
            [self initSpToDa];
            [self initCount];
            // 上位に通知
            //[delegate recieveClientAuthenticationEnd:data];
            break;
        case COMMAND_APP_INFO_RES:
            // MARK: 24H
            NSLog(@"T/Cアプリ情報応答(24H)");
            //[self printlogReceive:data];
            // T/Cアプリ情報応答
            if (![self checkDataMatch:COMMAND_NOTIFY_APP_INFO]) {
                return;
            }
            
            // MARK: コール機能 35H
            [self sendVehicleInfo:data];
            
            // T/Cアプリ情報応答、送信したデータを削除する
            [self initSpToDa];
            [self initCount];
            // 上位に通知
            // [delegate recieveAppInfoRes:data];
            break;
        case COMMAND_VEHICLE_INFO_RES:
            // MARK: 25H
            NSLog(@"車両情報機能設定応答(25H)");
            //[self printlogReceive:data];
            // 車両情報機能設定応答
            if (![self checkDataMatch:COMMAND_NOTIFY_VEHICLE_INFO]) {
                return;
            }
            // 車両情報機能設定応答、送信したデータを削除する
            [self initSpToDa];
            [self initCount];
            // 上位に通知
            //[delegate receiveVehicleInfo:data];
            break;
        case COMMAND_TRIPINFO_RECEIVE:
            NSLog(@"Trip情報取得応答(22H)");
            //[self printlogReceive:data];
            // Trip情報取得応答 (SP → DA)
            if (![self checkDataMatch:COMMAND_TRIPINFOREQUEST]) {
                return;
            }
            // Trip情報取得応答を受信した為、送信したデータを削除する
            [self initSpToDa];
            [self initCount];
        case COMMAND_TRIPINFONOTIFY:
            NSLog(@"trip情報通知(44H)");
            //[self printlogReceive:data];
            // trip情報通知 (DA→SP)
            //            if (![self checkDataMatch:COMMAND_CLIENTAUTHEND]) {
            //                return;
            //            }
            // trip確認送信
            [self sendTripInfo:data];
            
            // 上位に通知
            //[delegate recieveTripInfo:data];
            break;
        default:
            // 何もしない
            return;
            break;
    }
    
    //    // 正常のデータを受信したので格納する
    //    carInfo.sendData = data;
}

/**
 * @brief コマンド一致チェック
 * @param コマンド種別
 * @return YES:一致 NO:不一致
 */
-(BOOL)checkDataMatch:(uint8_t)cmdType
{
    // 前回送った電文とシーケンス番号が保存されている
    //DACarInfo *carInfo = [DACarInfo getInstance];
    //    NSLog(@"チェックデータ引数 = %c",cmdType);
    //    NSLog(@"チェックデータ内部データ = %@",carInfo.sendData);
    
    //    const unsigned char* bytes = [carInfo.sendData bytes];
    
    if (spToDaData == nil) {
        // 送信できていないためNG
        return NO;
    }
    // 送信データ
    const unsigned char* bytes = [spToDaData bytes];
    NSLog(@"%s",bytes);
    // コマンド種別一致チェック
    if (cmdType == bytes[0]) {
        NSLog(@"送信したデータの応答である");
        //        NSLog(@"シーケンス番号比較%@",[self convertSeqNoToHEX:seqNo]);
        //        NSLog(@"シーケンス番号比較%@",[carInfo.sendData subdataWithRange:NSMakeRange(7, 2)]);
        NSLog(@"シーケンスチェックOK");
        return YES;
//        if ([[self convertSeqNoToHEX:seqNo] isEqualToData:[carInfo.sendData subdataWithRange:NSMakeRange(7, 2)]]) {
//            NSLog(@"シーケンスチェックOK");
//            return YES;
//        } else {
//            NSLog(@"シーケンスチェックNG");
//        }
        
    } else {
        NSLog(@"送信したデータの応答である");
    }
    return NO;
}

/**
 * @brief 現在時刻取得要求
 */
-(void)getRequestTime:(NSData *)data
{
    // シーケンス番号
    int seq = [self convertSeqNoToDEX:data];
    // ECODE
    eCode = [[[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(10, 40)] encoding:NSASCIIStringEncoding] copy];
    //    NSString *strin = ecode;
    
    //VIN
    NSString *vin = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(43, 24)] encoding:NSASCIIStringEncoding];
}




@end
