//
//  VIResourceLoaderManager.m
//  VIMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import "VIResourceLoaderManager.h"
#import "VIResourceLoader.h"

static NSString *kCacheScheme = @"vimediacache://";

@interface VIResourceLoaderManager () <VIResourceLoaderDelegate>

@property (nonatomic, strong) NSMutableDictionary<id<NSCoding>, VIResourceLoader *> *loaders;

@end

@implementation VIResourceLoaderManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _loaders = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)cleanCache {
    [self.loaders removeAllObjects];
}

- (void)cancelLoaders {
    [self.loaders enumerateKeysAndObjectsUsingBlock:^(id<NSCoding>  _Nonnull key, VIResourceLoader * _Nonnull obj, BOOL * _Nonnull stop) {
        [obj cancel];
    }];
    [self.loaders removeAllObjects];
}

#pragma mark - AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest  {
    NSURL *resourceURL = [loadingRequest.request URL];
    if ([resourceURL.absoluteString hasPrefix:kCacheScheme]) {
        VIResourceLoader *loader = [self loaderForRequest:loadingRequest];
        if (!loader) {
            NSURL *originURL = nil;
            NSString *originStr = [resourceURL absoluteString];
            originStr = [originStr stringByReplacingOccurrencesOfString:kCacheScheme withString:@""];
            originURL = [NSURL URLWithString:originStr];
            loader = [[VIResourceLoader alloc] initWithURL:originURL];
            loader.delegate = self;
            NSString *key = [self keyForResourceLoaderWithURL:resourceURL];
            self.loaders[key] = loader;
        }
        [loader addRequest:loadingRequest];
        return YES;
    }

    return NO;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    VIResourceLoader *loader = [self loaderForRequest:loadingRequest];
    [loader removeRequest:loadingRequest];
}

#pragma mark - VIResourceLoaderDelegate

- (void)resourceLoader:(VIResourceLoader *)resourceLoader didFailWithError:(NSError *)error {
    [resourceLoader cancel];
    if ([self.delegate respondsToSelector:@selector(resourceLoaderManagerLoadURL:didFailWithError:)]) {
        [self.delegate resourceLoaderManagerLoadURL:resourceLoader.url didFailWithError:error];
    }
}

#pragma mark - Helper

- (NSString *)keyForResourceLoaderWithURL:(NSURL *)requestURL {
    if([[requestURL absoluteString] hasPrefix:kCacheScheme]){
        NSString *s = requestURL.absoluteString;
        return s;
    }
    return nil;
}

- (VIResourceLoader *)loaderForRequest:(AVAssetResourceLoadingRequest *)request {
    NSString *requestKey = [self keyForResourceLoaderWithURL:request.request.URL];
    VIResourceLoader *loader = self.loaders[requestKey];
    return loader;
}

@end

@implementation VIResourceLoaderManager (Convenient)

+ (NSURL *)assetURLWithURL:(NSURL *)url {
    if (!url) {
        return nil;
    }

    // 获取原始 URL 的绝对字符串
    NSString *originalURLString = [url absoluteString];
    // 对原始 URL 进行百分号解码，防止重复编码
    NSString *decodedURLString = [originalURLString stringByRemovingPercentEncoding];
    // 对解码后的 URL 进行重新编码
    NSString *encodedURLString = [decodedURLString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLFragmentAllowedCharacterSet]];
    // 拼接自定义 Scheme
    NSString *cacheURLString = [NSString stringWithFormat:@"%@%@", kCacheScheme, encodedURLString];
    // 创建 NSURL 对象
    NSURL *assetURL = [NSURL URLWithString:cacheURLString];
    return assetURL;
}

- (AVPlayerItem *)playerItemWithURL:(NSURL *)url {
    NSURL *assetURL = [VIResourceLoaderManager assetURLWithURL:url];
    AVURLAsset *urlAsset = [AVURLAsset URLAssetWithURL:assetURL options:nil];
    [urlAsset.resourceLoader setDelegate:self queue:dispatch_get_main_queue()];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:urlAsset];
    if ([playerItem respondsToSelector:@selector(setCanUseNetworkResourcesForLiveStreamingWhilePaused:)]) {
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = YES;
    }
    return playerItem;
}

@end
