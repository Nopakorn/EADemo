//
//  DACommand.h
//  EADASample
//
//  Created by Nonthawatt P on 31/5/2562 BE.
//  Copyright © 2562 OTR. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DACommand : NSObject{
@private

    int         nextPioTransactionID_;          //送信電文の電文送信番号。使用したら加算し、次に備える。
    int         pioDaTransactionID_;
    
    // 現在の送信回数
    int connectCnt;
    
    // 送信したシーケンス番号
    int seqNo;
    // 送信するデータ
    NSData *spToDaData;
}

@property (nonatomic, retain) NSString *eCode;

#pragma mark -------------------------------------
// DAに対して送信を行う
-(NSData*)daSendMessage:(NSData *)getData;
// チェックサム作成
-(NSData*)checkSum:(int)datalen byte:(NSData*) commandCls;
// 目的地到着データ通知確認
-(NSData*)sendArriveRes:(NSData*)getData;

-(NSData*)sendRequestTime:(NSData *)getData;

// 接続通知コマンドを生成
-(NSData*)sendNotifyConnect;

// +Boff確認コマンドを生成
-(NSData*)sendBatteryInfo:(NSData*)getData;

//クライアント認証開始確認
-(NSData*)sendClientStart:(NSData*)getData;

// HMAC確認
-(NSData*)sendHMACResponse:(NSData*)getData;

// Trip応答コマンドを送信
-(NSData*)sendTripInfo:(NSData *)getData;

// Trip情報取得要求コマンドを送信(32H)
-(NSData*)sendGetTripInfo;

// 目的地設定要求コマンドを送信(70H)
-(NSData*)sendDesitinationRewuestDataWithFromParam:(NSData *)spData;

// 目的地転送要求コマンドを送信(71H)
-(NSData*)sendTransferDestination;
/**
 * @brief 目的地設定データ通知確認
 */
-(NSData*)senfDestinationSetting:(NSData*)getData;

// 登録地設定要求コマンドを送信(72H)
-(NSData*)sendRegistrationPointDataWithFromParam:(NSData*)data;

// 周辺施設設定要求コマンドを送信(73H)
-(NSData*)sendAroundDataWithFromParam:(NSData*)spData;

// サーバー乱数通知を送信(74H)
-(NSData*)sendRandomNumber:(NSData*)spData;

// Trip情報アップロード結果通知(57H)
-(NSData*)sendTripInfoResult:(NSData*)getData result:(BOOL)isSuccess;

// TODO:単体テスト仕様書に追加
// 車両情報取得要求
-(NSData*)sendCarInfo;

// HMAC確認を送信(53H)
-(NSData*)sendHMACResponse;

// クライアント認証完了通知を送信(33H)
-(NSData*)sendClientEnd:(NSData*)spData;

-(NSData*)sendAppInfo:(NSData*) getData;

- (void) preceivedData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
