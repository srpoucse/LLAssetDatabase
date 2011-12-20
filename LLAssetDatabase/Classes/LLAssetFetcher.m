//
//  LLAssetFetcher.m
//  LLSample
//
//  Created by Glenn Wolters on 11/29/11.
//  Copyright (c) 2011 OMGWTFBBQ. All rights reserved.
//

#import "LLAssetFetcher.h"

@implementation LLAssetFetcher

@synthesize completionBlock = __completionBlock;
@synthesize failureBlock = __failureBlock;

+(void)assetForALAssetURL:(NSURL *)assetURL completion:(LLAssetResponseBlock)completionBlock failure:(LLAssetFailureBlock)failureBlock {
	ALAssetsLibrary *library = [ALAssetsLibrary sharedLibrary];
	[library assetForURL:assetURL resultBlock:^(ALAsset *asset) {
		completionBlock(asset);
		
	} failureBlock:^(NSError *error) {
		failureBlock(error);
	}];
}

+(ALAsset *)assetForAssetURL:(NSURL *)assetURL {
    NSConditionLock *lock = [[NSConditionLock alloc] initWithCondition:LLAssetDatabaseWorking];
    
    __block ALAsset *assetToReturn = nil;
    
	ALAssetsLibrary *library = [ALAssetsLibrary sharedLibrary];
	[library assetForURL:assetURL resultBlock:^(ALAsset *asset) {
        assetToReturn = [asset retain];
        NSLog(@"ASSET TO RETURN %@", asset);
        [lock lockWhenCondition:LLAssetDatabaseDone];
        [lock unlock];


	} failureBlock:^(NSError *error) {
        [lock lock];
        [lock unlockWithCondition:LLAssetDatabaseDone];        
	}];    
    
    [lock lock];
    [lock unlockWithCondition:LLAssetDatabaseDone];
    [lock release];
    
    NSLog(@"ASSET TO RETURN %@", assetToReturn);
    return assetToReturn;
}

-(void)assetsBetweenDate:(NSDate *)startDate endDate:(NSDate *)endDate progress:(LLAssetProgressBlock)progress completion:(LLAssetsBlock)completion {
    if (!startDate || !endDate) {
        return;
    }
    
	dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		
		NSConditionLock *lock = [[NSConditionLock alloc] initWithCondition:LLAssetDatabaseWorking];
		
		NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"LLAsset"];
		
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"date > %@ && date < %@", startDate, endDate];
		[fetchRequest setPredicate:predicate];
		
		NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO];
		[fetchRequest setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
		
		NSError *error;
		NSArray *assets = [[[LLAssetDatabase database] managedObjectContext] executeFetchRequest:fetchRequest error:&error];
		
		__block NSMutableArray *assetsArray = [[NSMutableArray alloc] init];
		
		NSLog(@"NUMBER OF ASSETS %i", [assets count]);
		
		__block int assetFetcherReturnCount = 0;
		
		for (int x = 0; x <= [assets count]; x++) {
            if (shouldStop) {
                return;
            }

			if (![assets count]) {
                //				[lock lock];
//				[lock unlockWithCondition:LLAssetDatabaseDone];
				break;
			} 
			else if (x == [assets count]) {
				break;
			}
            			
			LLAsset *asset = [assets objectAtIndex:x];
			
			LLAssetURL *assetURL = [[asset urls] anyObject];
			
			NSURL *url = [NSURL URLWithString:assetURL.url];
			
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                if (shouldStop) {
                    [lock lock];
                    [lock unlockWithCondition:LLAssetDatabaseDone];
                    return;
                }
				[LLAssetFetcher assetForALAssetURL:url completion:^(ALAsset *asset) {

                    if (asset) {
                        [assetsArray addObject:asset];
                    }					
                    
					assetFetcherReturnCount++;
                    
					if (progress) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
							progress(asset);	
						});						
					}
                    
					if (assetFetcherReturnCount == [assets count]) {
						[lock lock];
						[lock unlockWithCondition:LLAssetDatabaseDone];
					}
					
				}failure:^(NSError *error){
					assetFetcherReturnCount++;
					
					if (assetFetcherReturnCount == [assets count]) {
						[lock lock];
						[lock unlockWithCondition:LLAssetDatabaseDone];
					}
				}];					
			});
			
		}
		
		[lock lockWhenCondition:LLAssetDatabaseDone];
		[lock unlock];
		
		[lock release];
		lock = nil;
		
		NSLog(@"RETURN");
		[assetsArray autorelease];	
		completion(assetsArray);
	});
}

-(void)assetsBetweenDate:(NSDate *)startDate endDate:(NSDate *)endDate completion:(LLAssetsBlock)completion {
	[self assetsBetweenDate:startDate endDate:endDate progress:nil completion:completion];
}

-(void)cancel {
    shouldStop = YES;
    NSLog(@"CANCEL ASSET FETCH");
}

@end
