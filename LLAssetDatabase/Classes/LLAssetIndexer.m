//
//  LLAssetIndexer.m
//  AssetDatabase
//
//  Created by Glenn Wolters on 11/28/11.
//  Copyright (c) 2011 OMGWTFBBQ. All rights reserved.
//

#import "LLAssetIndexer.h"

@implementation LLAssetIndexer

@synthesize managedObjectContext = __managedObjectContext;
@synthesize assetsGroup = __assetsGroup;
@synthesize isExecuting = __isExecuting;
@synthesize isFinished = __isFinished;
@synthesize llAssetsGroup = __llAssetsGroup;
@synthesize illegalIndexes;

-(void)dealloc {
	[__managedObjectContext release];
	[__assetsGroup release];
	[__llAssetsGroup release];
	[illegalIndexes release];
    
	[super dealloc];
}


-(id)initWithAssetGroup:(ALAssetsGroup *)assetsGroup {
	self = [super init];
	if (self) {
		
		[self setAssetsGroup:assetsGroup];
				
		return self;
	}
	
	return nil;
}

-(void)start {
	__block NSUInteger count = 0;
    NSUInteger saveCount = MAX(25, [[self assetsGroup] numberOfAssets]/10);

    LLAssetGroup *llAssetGroup = [LLAssetGroup LLAssetGroupWithALAssetsGroup:[self assetsGroup] managedObjectContext:[self managedObjectContext]];
    [self setLlAssetsGroup:llAssetGroup];

    @autoreleasepool {
        
        if ([[self assetsGroup] numberOfAssets] == 0) {
            //Clean enumerate
            NSArray *exisitingAssets = [self existingAssetsForGroup:llAssetGroup];
            ALAssetsGroupEnumerationResultsBlock cleanBlock = ^(ALAsset *asset, NSUInteger index, BOOL *stop){
                if ([self isCancelled]) {
                    //            NSLog(@"CANCELLED ENUMERATING %@", [__assetsGroup valueForProperty:ALAssetsGroupPropertyName]);
                    *stop = YES;
                }
                else if (*stop) {
                    [self saveContext];
                    [self finish];
                }
                
                if (asset) {
                    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
                        LLAssetURL *assetURL = (LLAssetURL *)evaluatedObject;
                        
                        NSDictionary *urls = [asset valueForProperty:ALAssetPropertyURLs];
                        for (NSString *key in [urls allKeys]) {
                            NSString *URL =	[[urls objectForKey:key] absoluteString];
                            
                            if ([URL isEqualToString:assetURL.url]) {
                                return YES;
                            }
                        }
                        return NO;
                    }];
                    if (![[exisitingAssets filteredArrayUsingPredicate:predicate] count]) {
                        //create asset
                        //add asset to group
                        LLAsset *llAsset = [LLAsset createLLAssetWithALAsset:asset managedObjectContext:[self managedObjectContext]];
                        [[self llAssetsGroup] addAssetsObject:llAsset];
                        
                    }
                    else {
                        //nothing
                    }
                    
                    count++;
                }

                if (count == saveCount) {
                    numberOfChanges++;
                    [self saveContext];
                    count = 0;
                }

            };
            [[self assetsGroup] enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:cleanBlock];
        }
        else {
            //Update enumerate
            ALAssetsGroupEnumerationResultsBlock updateBlock = ^(ALAsset *asset, NSUInteger index, BOOL *stop){
                if ([self isCancelled]) {

                    *stop = YES;
                }
                else if (*stop) {
                    [self saveContext];
                    [self finish];
                }

                if (asset && ![LLAsset doesALAssetExist:asset managedObjectContext:[self managedObjectContext]]) {
                    LLAsset *llAsset = [LLAsset LLAssetWithALAsset:asset managedObjectContext:[self managedObjectContext]];
                    [[self llAssetsGroup] addAssetsObject:llAsset];
                    count++;
                }
                
                if (count == saveCount) {
                    numberOfChanges++;
                    [self saveContext];
                    count = 0;
                }

            };
            
            [[self assetsGroup] enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:updateBlock];
            
        }
    }
    
    [self willChangeValueForKey:@"isExecuting"];
    __isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
}

-(BOOL)isConcurrent {
	return YES;
}

-(void)finish {

    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    __isExecuting = NO;
    __isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];  
}

-(NSIndexSet *)illegalIndexes {
    if (illegalIndexes) {
        return illegalIndexes;
    }
    
    illegalIndexes = [[NSMutableIndexSet alloc] init];
    return illegalIndexes;
}

-(NSArray *)existingAssetsForGroup:(LLAssetGroup *)group {
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"LLAssetURL"];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"url" ascending:NO];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    
    NSError *error;
    return [[self managedObjectContext] executeFetchRequest:fetchRequest error:&error];
}

-(void)saveContext {
	NSError *error;
	[[self managedObjectContext] save:&error];	
}

-(NSManagedObjectContext *)managedObjectContext {
	if (__managedObjectContext) {
		return __managedObjectContext;
	}
	
	NSPersistentStoreCoordinator *persistentStoreCoordinator = [LLAssetDatabase persistentStoreCoordinator];
	
	__managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
	[__managedObjectContext setPersistentStoreCoordinator:persistentStoreCoordinator];
	[__managedObjectContext setUndoManager:nil];
	return __managedObjectContext;
}



@end
