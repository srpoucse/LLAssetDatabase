//
//  LLAssetFetcher.h
//  LLSample
//
//  Created by Glenn Wolters on 11/29/11.
//  Copyright (c) 2011 OMGWTFBBQ. All rights reserved.
//

#import "LLAssetDatabase.h"

@class LLAssetFetcher;

typedef void (^LLAssetResponseBlock)(ALAsset *asset);
typedef void (^LLAssetFailureBlock)(NSError *error);
typedef void (^LLAssetsBlock)(NSArray *assets);
typedef void (^LLAssetProgressBlock)(ALAsset *asset);

enum {
	LLAssetDatabaseDone,
	LLAssetDatabaseWorking
	
} LLAssetDatabaseConditionLock;

@interface LLAssetFetcher : NSObject {
    BOOL shouldStop;
}

+(void)assetForALAssetURL:(NSURL *)assetURL completion:(LLAssetResponseBlock)completionBlock failure:(LLAssetFailureBlock)failureBlock;
+(ALAsset *)assetForAssetURL:(NSURL *)assetURL;

-(void)assetsBetweenDate:(NSDate *)startDate endDate:(NSDate *)endDate completion:(LLAssetsBlock)completion;
-(void)assetsBetweenDate:(NSDate *)startDate endDate:(NSDate *)endDate progress:(LLAssetProgressBlock)progress completion:(LLAssetsBlock)completion;

-(void)cancel;

@property (nonatomic, assign) LLAssetResponseBlock completionBlock;
@property (nonatomic, assign) LLAssetFailureBlock failureBlock;

@end
