//
//  NSURLProtocolCustom.m
//  JFQ
//
//  Created by 李明悦 on 2017/6/29.
//  Copyright © 2017年 LinLiLe. All rights reserved.
//

#import "NSURLProtocolCustom.h"
#import "NSString+PJR.h"
#import "UIImageView+WebCache.h"
#import "NSData+ImageContentType.h"
#import "UIImage+MultiFormat.h"

static NSString* const FilteredKey = @"FilteredKey";

@interface NSURLProtocolCustom ()

@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, strong) NSURLConnection *connection;
@end

@implementation NSURLProtocolCustom

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    NSURL *url = request.URL;
    NSString *scheme = [url scheme];
    
    if ( ([scheme caseInsensitiveCompare:@"http"] == NSOrderedSame ||
          [scheme caseInsensitiveCompare:@"https"] == NSOrderedSame))
    {
        NSString *requestUrl = url.absoluteString;
        
        NSLog(@"HTTPMethod:%@",request.HTTPMethod);
        NSLog(@"Protocol URL:%@",requestUrl);
        
        NSString *extension = url.pathExtension;
        
        if ([requestUrl containsString:@"://resource"]) {
            //基础静态资源，h5上已经做了统一路径处理，可以以此：://resource 前序来判断是否需要拦截
            if ([extension isEqualToString:@"js"] || [extension isEqualToString:@"css"]) {
                NSString *fileName = [[request.URL.absoluteString componentsSeparatedByString:@"/"].lastObject componentsSeparatedByString:@"?"][0];
                NSLog(@"fileName is %@",fileName);
                //从bundle中读取
                NSString *path = [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
                //从沙箱读取
//                NSString *docPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
//                NSString *path = [docPath stringByAppendingPathComponent:fileName];
                
                if (path) {
                    NSLog(@"the file is local file");
                    return [NSURLProtocol propertyForKey:FilteredKey inRequest:request] == nil;
                }
            }
        }
        
        if ([extension isPicResource]) {
            //用sdwebimage来加载图片，间接实现h5图片缓存功能
            return [NSURLProtocol propertyForKey:FilteredKey inRequest:request]== nil;
        }
        
    }
    
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    NSURL *url = super.request.URL;
    NSString *requestUrl = url.absoluteString;
    NSString *extension = url.pathExtension;
    
    NSMutableURLRequest *mutableReqeust = [[self request] mutableCopy];
    //标记该请求已经处理
    [NSURLProtocol setProperty:@YES forKey:FilteredKey inRequest:mutableReqeust];
    
    if ([requestUrl containsString:@"://resource"]) {
        //获取本地资源路径
        NSString *fileName = [[requestUrl componentsSeparatedByString:@"/"].lastObject componentsSeparatedByString:@"?"][0];
        //从bundle中读取
        NSString *path = [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
        //从沙箱读取
//        NSString *docPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
//        NSString *path = [docPath stringByAppendingPathComponent:fileName];
        if (path) {
            //根据路径获取MIMEType
            CFStringRef pathExtension = (__bridge_retained CFStringRef)[path pathExtension];
            CFStringRef type = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension, NULL);
            CFRelease(pathExtension);
            
            //The UTI can be converted to a mime type:
            NSString *mimeType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass(type, kUTTagClassMIMEType);
            if (type != NULL)
                CFRelease(type);
            
            //加载本地资源
            NSData *data = [NSData dataWithContentsOfFile:path];
            [self sendResponseWithData:data mimeType:mimeType];
            
            return;
        }else{
            NSLog(@"%@ is not find",fileName);
        }
    }else if([extension isPicResource]){
        //处理图片缓存
        NSString *key = [[SDWebImageManager sharedManager] cacheKeyForURL:url];
        UIImage *img = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:key];
        
        if (img) {
            //存在图片缓存
            NSData *data = nil;
            if ([extension isEqualToString:@"png"]) {
                data = UIImagePNGRepresentation(img);
            }else{
                data = UIImageJPEGRepresentation(img, 1);
            }
            NSString *mimeType = [NSData sd_contentTypeForImageData:data];
            [self sendResponseWithData:data mimeType:mimeType];
            
            return ;
        }
        
        self.connection = [NSURLConnection connectionWithRequest:mutableReqeust delegate:self];
    }
}

- (void)stopLoading
{
    NSLog(@"stopLoading from networld");
    if (self.connection) {
        [self.connection cancel];
    }
}

- (void)sendResponseWithData:(NSData *)data mimeType:(nullable NSString *)mimeType
{
    NSLog(@"sendResponseWithData start");
    // 这里需要用到MIMEType
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:super.request.URL
                                                        MIMEType:mimeType
                                           expectedContentLength:data.length
                                                textEncodingName:nil];
    
    if ([self client]) {
        if ([self.client respondsToSelector:@selector(URLProtocol:didReceiveResponse:cacheStoragePolicy:)]) {
            [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        }
        if ([self.client respondsToSelector:@selector(URLProtocol:didLoadData:)]) {
            [[self client] URLProtocol:self didLoadData:data];
        }
        if ([self.client respondsToSelector:@selector(URLProtocolDidFinishLoading:)]) {
            [[self client] URLProtocolDidFinishLoading:self];
        }
    }
    
    NSLog(@"sendResponseWithData end");
}

#pragma mark- NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    
    [self.client URLProtocol:self didFailWithError:error];
}

#pragma mark - NSURLConnectionDataDelegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.responseData = [[NSMutableData alloc] init];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
    [self.client URLProtocol:self didLoadData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    //缓存图片
    UIImage *cacheImage = [UIImage sd_imageWithData:self.responseData];
    NSString *key = [[SDWebImageManager sharedManager] cacheKeyForURL:self.request.URL];
    
    [[SDImageCache sharedImageCache] storeImage:cacheImage
                           recalculateFromImage:NO
                                      imageData:self.responseData
                                         forKey:key
                                         toDisk:YES];
    
    [self.client URLProtocolDidFinishLoading:self];
}

@end
