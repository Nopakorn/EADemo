//
//  EADemoTests.m
//  EADemoTests
//
//  Created by Infrastructure on 4/6/2562 BE.
//  Copyright © 2562 DTS. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "DACommand.h"
#import "EADSessionController.h"
@interface EADemoTests : XCTestCase

@end

@implementation EADemoTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    DACommand *daCommand = [[DACommand alloc] init];
    EADSessionController *sessionController = [[EADSessionController alloc] init];
    NSData *data = [self createData:@""];
    [daCommand preceivedData:data];
}

-(void) testtest {
    NSString *input = @"7e0096348006706ec47401000000209cda6f01000000c865618b0100000077c7cb000100000000fffe740068 002e0063006f002e0064006d00610070002e0073006d00670062002e00740068002e006f007400720074002e00310032 0033003200fffe63006f006d002e0067002d0062006f006f006b002e007400730063002e00740063006f006e006e0065 00630074002e00650064006100ce4d7e";
    NSData *cs = [self createData:input];
    DACommand *daCommand = [[DACommand alloc] init];
    NSData *result = [daCommand sendAppInfo:cs];
    NSData *ecodedata = [self createData:@"303133303059373230303333313430304b5930303030303030303030303030303030303030303030"];
    
    NSString *test = [[NSString alloc] initWithData:ecodedata encoding:NSUTF8StringEncoding];
}






- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

- (NSData *)createData:(NSString *)input {
    const char *buf = [input UTF8String];
    NSMutableData *data = [NSMutableData data];
    if (buf)
    {
        uint32_t len = (uint32_t)strlen(buf);
        
        char singleNumberString[3] = {'\0', '\0', '\0'};
        uint32_t singleNumber = 0;
        for(uint32_t i = 0 ; i < len; i+=2)
        {
            if ( ((i+1) < len) && isxdigit(buf[i]) && (isxdigit(buf[i+1])) )
            {
                singleNumberString[0] = buf[i];
                singleNumberString[1] = buf[i + 1];
                sscanf(singleNumberString, "%x", &singleNumber);
                uint8_t tmp = (uint8_t)(singleNumber & 0x000000FF);
                [data appendBytes:(void *)(&tmp) length:1];
            }
            else
            {
                break;
            }
        }
    }
    return data;
}

@end
