//
//  ShareViewController.m
//  OpenWith - Share Extension
//

//
// The MIT License (MIT)
//
// Copyright (c) 2017 Jean-Christophe Hoelt
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import <UIKit/UIKit.h>
#import <Social/Social.h>
#import "ShareViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>

/*
 * Add base64 export to NSData
 */
@interface NSData (Base64)
- (NSString*)convertToBase64;
@end

@implementation NSData (Base64)
- (NSString*)convertToBase64 {
    const uint8_t* input = (const uint8_t*)[self bytes];
    NSInteger length = [self length];
    
    static char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
    
    NSMutableData* data = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
    uint8_t* output = (uint8_t*)data.mutableBytes;
    
    NSInteger i;
    for (i=0; i < length; i += 3) {
        NSInteger value = 0;
        NSInteger j;
        for (j = i; j < (i + 3); j++) {
            value <<= 8;
            
            if (j < length) {
                value |= (0xFF & input[j]);
            }
        }
        
        NSInteger theIndex = (i / 3) * 4;
        output[theIndex + 0] =                    table[(value >> 18) & 0x3F];
        output[theIndex + 1] =                    table[(value >> 12) & 0x3F];
        output[theIndex + 2] = (i + 1) < length ? table[(value >> 6)  & 0x3F] : '=';
        output[theIndex + 3] = (i + 2) < length ? table[(value >> 0)  & 0x3F] : '=';
    }
    
    NSString *ret = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
#if ARC_DISABLED
    [ret autorelease];
#endif
    return ret;
}
@end

@interface ShareViewController : SLComposeServiceViewController <UIAlertViewDelegate> {
    long _verbosityLevel;
    NSUserDefaults *_userDefaults;
    NSString *_backURL;
    
    //- (void)sendResults
}
@property (nonatomic) long verbosityLevel;
@property (nonatomic,retain) NSUserDefaults *userDefaults;
@property (nonatomic,retain) NSString *backURL;
@end

/*
 * Constants
 */

#define VERBOSITY_DEBUG  0
#define VERBOSITY_INFO  10
#define VERBOSITY_WARN  20
#define VERBOSITY_ERROR 30

@implementation ShareViewController

@synthesize verbosityLevel = _verbosityLevel;
@synthesize userDefaults = _userDefaults;
@synthesize backURL = _backURL;

- (void) log:(int)level message:(NSString*)message {
    if (level >= self.verbosityLevel) {
        NSLog(@"[ShareViewController.m]%@", message);
    }
}
- (void) debug:(NSString*)message { [self log:VERBOSITY_DEBUG message:message]; }
- (void) info:(NSString*)message { [self log:VERBOSITY_INFO message:message]; }
- (void) warn:(NSString*)message { [self log:VERBOSITY_WARN message:message]; }
- (void) error:(NSString*)message { [self log:VERBOSITY_ERROR message:message]; }

- (void) setup {
    self.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:SHAREEXT_GROUP_IDENTIFIER];
    self.verbosityLevel = [self.userDefaults integerForKey:@"verbosityLevel"];
    [self debug:@"[setup]"];
}

- (BOOL) isContentValid {
    return YES;
}

//+ (NSURL*)getSharedContainerURLPath
//{
//    NSFileManager *fm = [NSFileManager defaultManager];
//
//    NSURL *groupContainerURL = [fm containerURLForSecurityApplicationGroupIdentifier:SHAREEXT_GROUP_IDENTIFIER];
//
//    return groupContainerURL;
//}

//- (void) openURL:(nonnull NSURL *)url {
//
//    SEL selector = NSSelectorFromString(@"openURL:options:completionHandler:");
//
//    UIResponder* responder = self;
//    while ((responder = [responder nextResponder]) != nil) {
//        NSLog(@"responder = %@", responder);
//        if([responder respondsToSelector:selector] == true) {
//            NSMethodSignature *methodSignature = [responder methodSignatureForSelector:selector];
//            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
//
//            // Arguments
//            NSDictionary<NSString *, id> *options = [NSDictionary dictionary];
//            void (^completion)(BOOL success) = ^void(BOOL success) {
//                NSLog(@"Completions block: %i", success);
//            };
//
//            [invocation setTarget: responder];
//            [invocation setSelector: selector];
//            [invocation setArgument: &url atIndex: 2];
//            // no options and completion function. Remove unused code -tanli
//            // [invocation setArgument: &options atIndex:3];
//            // [invocation setArgument: &completion atIndex: 4];
//            [invocation invoke];
//            break;
//        }
//    }
//}


//- (nonnull NSString *) assembleDestinationUrlForImageOutput: (nonnull NSString *) filename fileManager: (NSFileManager ) {
//    NSURL *groupContainerURL = [fileManager containerURLForSecurityApplicationGroupIdentifier:SHAREEXT_GROUP_IDENTIFIER];
//
//    NSURL *writableUrl = [groupContainerURL URLByAppendingPathComponent:[filename stringByAppendingString:@".JPG"]];
//
//}

- (void) populateDictInfoForImage:(nonnull NSMutableDictionary *)dict writableUrl:(nonnull NSURL *)writableUrl mimeType:(nonnull NSString *)mimeType features:(nonnull NSArray *)features{
    
    NSString *fileUrl = [writableUrl absoluteURL].absoluteString;

    [dict setObject:fileUrl forKey:@"fileUrl"];
    
    [dict setObject:[writableUrl lastPathComponent] forKey:@"name"];
    
    [dict setObject:mimeType forKey:@"type"];
    
    [dict setValue:@YES forKey:@"processed"];

    if (features.count>0){
        CIQRCodeFeature *feature = [features objectAtIndex:0];
        [dict setObject: feature.messageString forKey:@"qrString"];
        NSLog(@"[ShareViewController.m: error check 1:]%@", feature.messageString);// feature.messageString;
    }


}

- (void) saveImage:(nonnull NSString *)filename image:(nonnull UIImage *) image  dict: (nonnull NSMutableDictionary *)dict{
    NSFileManager *fileManager  = [NSFileManager defaultManager];
    
    NSURL *groupContainerURL = [fileManager containerURLForSecurityApplicationGroupIdentifier:SHAREEXT_GROUP_IDENTIFIER];
    
    NSURL *writableUrl = [groupContainerURL URLByAppendingPathComponent:[filename stringByAppendingString:@".JPG"]];
    
    NSData *data = UIImageJPEGRepresentation(image, 1);
    
    if (![fileManager fileExistsAtPath: writableUrl.path]){
        [fileManager removeItemAtPath:writableUrl.path error: NULL];
    }
    
//
//    NSData *tmpData = UIImagePNGRepresentation(image);
    
    NSLog(@"[ShareViewController.m: save image with size:]%lu", data.length);// feature.messageString;



    [data writeToURL:writableUrl atomically:true];
    
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{ CIDetectorAccuracy : CIDetectorAccuracyHigh }];

        CIImage *ciImage = [CIImage imageWithData:data];
    
        NSArray *features = [detector featuresInImage: ciImage];//[CIImage imageWithCGImage:CGImageSourceCreateImageAtIndex(source, 0, nil)]];//  [CIImage
    [self populateDictInfoForImage:dict writableUrl:writableUrl mimeType:(NSString *)kUTTypeJPEG features:features];
//        if (features.count>0){
//            CIQRCodeFeature *feature = [features objectAtIndex:0];
//            [dict setObject: feature.messageString forKey:@"qrString"];
//            NSLog(@"[ShareViewController.m: error check 1:]%@", feature.messageString);// feature.messageString;
//        }
//
//    NSString *fileUrl = [writableUrl absoluteURL].absoluteString;
//
//    [dict setObject:fileUrl forKey:@"fileUrl"];
//
//    [dict setObject:[writableUrl lastPathComponent] forKey:@"name"];
//
//    [dict setObject:(NSString *)kUTTypeJPEG forKey:@"type"];

    
//    return writableUrl;
    //    return  (NSString*) kUTTypeJPEG;
    
}

- (void) copyImageFileToSharedDirectory:(nonnull NSURL *)fromURL dict: (nonnull NSMutableDictionary *)dict mimeType:(nonnull NSString*) mimeType{
    NSFileManager *fileManager  = [NSFileManager defaultManager];
    
    NSString *fileNameWithExtension = [fromURL lastPathComponent];
    NSURL *groupContainerURL = [fileManager containerURLForSecurityApplicationGroupIdentifier:SHAREEXT_GROUP_IDENTIFIER];
    
    NSURL *writableUrl = [groupContainerURL URLByAppendingPathComponent:fileNameWithExtension];
    
    if (![fileManager fileExistsAtPath: writableUrl.path]){
        [fileManager removeItemAtPath:writableUrl.path error: NULL];
    }
    [fileManager copyItemAtURL:fromURL toURL:writableUrl error:NULL];
    
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{ CIDetectorAccuracy : CIDetectorAccuracyHigh }];

        CIImage *ciImage = [CIImage imageWithContentsOfURL: fromURL];
    
        NSArray *features = [detector featuresInImage: ciImage];//[CIImage imageWithCGImage:CGImageSourceCreateImageAtIndex(source, 0, nil)]];//  [CIImage
    [self populateDictInfoForImage:dict writableUrl:writableUrl mimeType:mimeType features:features];
//        if (features.count>0){
//            CIQRCodeFeature *feature = [features objectAtIndex:0];
//            [dict setObject: feature.messageString forKey:@"qrString"];
//            NSLog(@"[ShareViewController.m: error check 1:]%@", feature.messageString);// feature.messageString;
//        }
//
//    NSString *fileUrl = [writableUrl absoluteURL].absoluteString;
//
//    [dict setObject:fileUrl forKey:@"fileUrl"];
//
//    [dict setObject:[writableUrl lastPathComponent] forKey:@"name"];
//
//    [dict setObject:mimeType forKey:@"type"];

    
//    return writableUrl;
    
}

- (void) openURL:(nonnull NSURL *)url {
    
    SEL selector = NSSelectorFromString(@"openURL:options:completionHandler:");
    
    UIResponder* responder = self;
    while ((responder = [responder nextResponder]) != nil) {
        NSLog(@"responder = %@", responder);
        if([responder respondsToSelector:selector] == true) {
            NSMethodSignature *methodSignature = [responder methodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
            
            // Arguments
            void (^completion)(BOOL success) = ^void(BOOL success) {
                NSLog(@"Completions block: %i", success);
                //                [self.extensionContext completeRequestReturningItems:@[] completionHandler:^void(BOOL success){
                ////                    usleep(1000000);
                //                    usleep(10000);
                //
                //                }];
                
                
            };
            if (@available(iOS 13.0, *)) {
                UISceneOpenExternalURLOptions * options = [[UISceneOpenExternalURLOptions alloc] init];
                options.universalLinksOnly = false;
                
            [invocation setTarget: responder];
            [invocation setSelector: selector];
            [invocation setArgument: &url atIndex: 2];
                [invocation setArgument: &options atIndex:3];
                [invocation setArgument: &completion atIndex: 4];
                [invocation invoke];
                break;
            } else {
                NSDictionary<NSString *, id> *options = [NSDictionary dictionary];
                
                [invocation setTarget: responder];
                [invocation setSelector: selector];
                [invocation setArgument: &url atIndex: 2];
                [invocation setArgument: &options atIndex:3];
                [invocation setArgument: &completion atIndex: 4];
            [invocation invoke];
            break;
        }
    }
    }
}


- (void) viewDidAppear:(BOOL)animated {
    [self.view endEditing:YES];
}

//- (void) didSelectPost {
//    [self debug:@"[didSelectPost]"];
//}

//- (NSArray *)imageImmediateLoadWithContentsOfUrl:(UIImage *) imageToRead {
//    //    NSData *_rawData = UIImagePNGRepresentation(imageToRead);
//    //    NSLog(@"[raw data]%@", [_rawData convertToBase64]);
//    CGImageRef imageRef = [imageToRead CGImage];
//    CGRect rect = CGRectMake(0.f, 0.f, CGImageGetWidth(imageRef), CGImageGetHeight(imageRef));
//    CGContextRef bitmapContext = CGBitmapContextCreate(NULL,
//                                                       rect.size.width,
//                                                       rect.size.height,
//                                                       CGImageGetBitsPerComponent(imageRef),
//                                                       CGImageGetBytesPerRow(imageRef),
//                                                       CGImageGetColorSpace(imageRef),
//                                                       CGImageGetBitmapInfo(imageRef)
//                                                       );
//    CGContextDrawImage(bitmapContext, rect, imageRef);
//    //    CGImageRef decompressedImageRef = CGBitmapContextCreateImage(bitmapContext);
//    NSData *bitmapData=CGBitmapContextGetData(bitmapContext);
//
//    CIImage *ciImage = [CIImage imageWithBitmapData:bitmapData bytesPerRow:CGImageGetBytesPerRow(imageRef) size:rect.size format:kCIFormatRG8 colorSpace:CGImageGetColorSpace(imageRef)];
//
//    //    CIImage *ciImage = [CIImage imageWithCGImage:decompressedImageRef];
//
//    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{ CIDetectorAccuracy : CIDetectorAccuracyHigh }];
//
//
//    NSArray *features = [detector featuresInImage: ciImage];//[CIImage imageWithCGImage:CGImageSourceCreateImageAtIndex(source, 0, nil)]];//  [CIImage imageWithData:_tmpdata]];
//
//    if (features.count>0){
//        CIQRCodeFeature *feature = [features objectAtIndex:0];
//        NSLog(@"[ShareViewController.m: error check 1:]%@", feature.messageString);// feature.messageString;
//    }
//
//
//    //    UIImage *decompressedImage = [UIImage imageWithCGImage:decompressedImageRef];
//    //    CGImageRelease(decompressedImageRef);
//    CGContextRelease(bitmapContext);
//    return features;
//    //    return decompressedImage;
//}

- (void) viewDidLoad {
    
    //- (void) didSelectPost {
    
    [self setup];
    [self debug:@"[viewDidLoad]"];
    
    __block unsigned long remainingAttachments = (unsigned long)((NSExtensionItem*)self.extensionContext.inputItems[0]).attachments.count;
    __block NSMutableArray *items = [[NSMutableArray alloc] init];
    __block NSDictionary *results = @{
                                          @"text" : self.contentText,
                                          @"backURL": self.backURL != nil ? self.backURL : @"",
                                          @"items": items,
                                      };
    
    __block unsigned int numUnnamedImage=0;
    
    
    
    for (NSItemProvider* itemProvider in ((NSExtensionItem*)self.extensionContext.inputItems[0]).attachments) {
        [self debug:[NSString stringWithFormat:@"item provider registered indentifiers = %@", itemProvider.registeredTypeIdentifiers]];
        // URL case
        // IMAGE case
        if ([itemProvider hasItemConformingToTypeIdentifier:@"public.image"]) {
            
            
            [self debug:[NSString stringWithFormat:@"item provider = %@", itemProvider]];
            
            // We will load from NSURL ourselves because it will always give use raw data, instead of UIImage. To save an UIImage, we have to do a format converstion,
            // whereas we want to perserve the original file.
            //            __block NSData *data = [[NSData alloc] init];
            //            [itemProvider loadItemForTypeIdentifier:@"public.image" options:nil completionHandler: ^(UIImage *image, NSError *error) {
            //                NSLog(@"[ShareViewController.m: error check 1.1:]%@", error);
            //            }];
            
            //            [itemProvider loadItemForTypeIdentifier:@"public.file-url" options:nil completionHandler: ^(id<NSSecureCoding> itemUrl, NSError *error) {
            //                NSLog(@"[ShareViewController.m: error check 1.2:]%@", error);
            //
            //                if([(NSObject*)itemUrl isKindOfClass:[NSURL class]]) {
            //                    NSURL *incomeURL = (NSURL*) itemUrl;
            ////                    NSData *_data = [NSData dataWithContentsOfURL:(NSURL*)item];
            ////                    image = [UIImage imageWithData:_data];
            //
            //                    CIImage *cgImage = [CIImage imageWithContentsOfURL:incomeURL];
            //
            //                    NSArray *features = [detector featuresInImage: cgImage];//[CIImage imageWithCGImage: image.CGImage]];
            //
            //                    NSLog(@"[feature check]%lu", (unsigned long) features.count);
            //                }
            //
            //            }];
            
            
            [itemProvider loadItemForTypeIdentifier:@"public.image" options:nil completionHandler: ^(id<NSSecureCoding> item, NSError *error) {
                --remainingAttachments;
                
                NSLog(@"[ShareViewController.m: error check 1.3:]%@", error);
                __block UIImage *image = [[UIImage alloc] init];
                //                NSString *suggestedName = nil;
                
                
//                NSString *mimeType= nil;//@"image/jpeg";
                
                //                NSFileManager *fileManager  = [NSFileManager defaultManager];
                //
                //                NSURL *groupContainerURL = [fileManager containerURLForSecurityApplicationGroupIdentifier:SHAREEXT_GROUP_IDENTIFIER];
                
//                NSURL *writableUrl = nil;
                
                NSString *uti = @"public.image";
                
                NSDictionary *passThroughMimetype = @{
                    @"image/png": @YES,
                    @"image/gif": @YES,
                    @"image/jpeg": @YES,
                    @"image/tiff": @YES,
                    @"png": @YES,
                    @"gif": @YES,
                    @"jpeg": @YES,
                    @"tiff": @YES
                };
                if([(NSObject*)item isKindOfClass:[NSURL class]]) {
                    NSURL *incomeURL = (NSURL*) item;
                    //                    NSData *_data = [NSData dataWithContentsOfURL:(NSURL*)item];
                    //                    image = [UIImage imageWithData:_data];
                    
//                    CIImage *cgImage = [CIImage imageWithContentsOfURL:incomeURL];
                    image = [UIImage imageWithContentsOfFile:incomeURL.path];
                    
//                    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options: @{ CIDetectorAccuracy : CIDetectorAccuracyHigh }];
                    //                    [detector featuresInImage: cgImage];
                    //                    NSArray *features = [detector featuresInImage: cgImage];//[CIImage imageWithCGImage: image.CGImage]];
                    //
                    //                    NSLog(@"[feature check]%lu", (unsigned long) features.count);
                    
                    
                    //                    NSLog(@"[CIImage size check]%lu", (unsigned long) _data.length);
                    //                    NSData *_tmpdata = UIImageJPEGRepresentation(image, 1);
                    
                    //                    CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)incomeURL, nil);
                    //                    CGImage cg = CGImageSourceCreateImageAtIndex(source, 0, nil);
                    //                    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{ CIDetectorAccuracy : CIDetectorAccuracyHigh }];
                    
                    //                CGImage *cgImage = (__bridge CGImage *)[CIImage imageWithCGImage: image.CGImage];
                    //                    CIImage *obj = [CIImage imageWithCGImage:CGImageSourceCreateImageAtIndex(source, 0, nil)];
                    
                    
                    //                    if (detector){
                    
                    //                        UIImage *imageRead =
                    //                    [self imageImmediateLoadWithContentsOfUrl: image];
                    //                        NSData *png = UIImagePNGRepresentation([self imageImmediateLoadWithContentsOfUrl: image]);
                    //                        CIImage *obj = [CIImage imageWithContentsOfURL:incomeURL];//:CGImageSourceCreateImageAtIndex(source, 0, nil)];
                    
                    //                        CIImage *obj = [CIImage imageWithData:png];//:CGImageSourceCreateImageAtIndex(source, 0, nil)];
                    //                        CIImage *obj = [CIImage imageWithCGImage: imageRead.CGImage];
                    //
                    //                        NSArray *features = [detector featuresInImage: obj];//[CIImage imageWithCGImage:CGImageSourceCreateImageAtIndex(source, 0, nil)]];//  [CIImage imageWithData:_tmpdata]];
                    //
                    //                        if (features.count>0){
                    //                            CIQRCodeFeature *feature = [features objectAtIndex:0];
                    //                            NSLog(@"[ShareViewController.m: error check 1:]%@", feature.messageString);// feature.messageString;
                    //                        }
                    //
                    //                        obj = nil;
                    //
                    //                    }
                    //                    detector = nil;
                    
                    
                    
                    //                    suggestedName = [(NSURL *)item lastPathComponent];
                    
                    
                    //                    else {
                    //                        registeredType = uti;
                    //                    }
                    
                    
                    
                    NSDictionary *_dict = @{
//                        //                                          @"text" : self.contentText,
//                        @"url" : fileUrl,//writablePath,//url,
                        @"uti"  : uti,
                        @"utis" : itemProvider.registeredTypeIdentifiers,
//                        @"name" : [writableUrl lastPathComponent],
//                        @"type" : mimeType,
                        @"processed": @YES,
                        //                                          @"qrString": qrString,
                    };
                    
                    NSMutableDictionary *dict = [NSMutableDictionary  new];
                    [dict addEntriesFromDictionary:_dict];
                    
                    if (self.contentText){
                        [dict setValue:self.contentText forKey:@"text"];
                    }

                    NSString *registeredType = nil;
                    if ([itemProvider.registeredTypeIdentifiers count] > 0) {
                        registeredType = itemProvider.registeredTypeIdentifiers[0];
                    };
                    NSString *mimeType =  [self mimeTypeFromUti:registeredType];

                    if (mimeType==nil || passThroughMimetype[mimeType]==nil){
                        //this is not a pass through type so we will transfer it to jpeg
                        NSString *fileName = [[incomeURL lastPathComponent] stringByDeletingPathExtension];
                        [self saveImage:fileName image:image dict:dict];
                        
//                        mimeType = (NSString *) kUTTypeJPEG;
                    }
                    else {
                        [self copyImageFileToSharedDirectory:incomeURL dict:dict mimeType:mimeType];
                    }
                    
                    
//                    NSString *fileUrl = [writableUrl absoluteURL].absoluteString;
                    
                    
//                    NSString *qrString = nil;
                    
//                                                        NSArray *features = [detector featuresInImage: [CIImage imageWithCGImage: image.CGImage]];
//
//                                                        if (features.count>0){
//                                                            CIQRCodeFeature *feature = [features objectAtIndex:0];
//                                                            qrString = feature.messageString;
//                                                        }
                    
//                    if (qrString){
//                        [dict setValue:qrString forKey:@"qrString"];
//                    }
                    
                    
                    
                    
                    [items addObject:dict];
                    if (remainingAttachments == 0) {
                        [self sendResults:results];
                    }
                    
                    
                    
                    //                NSString *documentsDirectoryPath = groupContainerURL.path;//[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
                    
                    
                }
                if([(NSObject*)item isKindOfClass:[UIImage class]]) {
                    //                                    data = UIImagePNGRepresentation((UIImage*)item);
                    image = (UIImage *)item;
                    numUnnamedImage++;
                    

                    //                    NSString *num = [NSString stringWithFormat:@"%d", numUnnamedImage];
                    //                    mimeType = @"image/jpeg";
                    
//                    mimeType = (NSString *)kUTTypeJPEG;
                    
                    
                    
                    
                    //                    writableUrl = [groupContainerURL URLByAppendingPathComponent:suggestedName];
                    //
                    //                    NSData *data = UIImagePNGRepresentation(image);
                    //
                    //                    if (![fileManager fileExistsAtPath: writableUrl.path]){
                    //                        [fileManager removeItemAtPath:writableUrl.path error: NULL];
                    //                    }
                    //
                    //                    [data writeToURL:writableUrl atomically:true];
//                    NSString *fileUrl = [writableUrl absoluteURL].absoluteString;
                    
                    NSDictionary *_dict = @{
                        //                                          @"text" : self.contentText,
//                        @"url" : fileUrl,//writablePath,//url,
                        @"uti"  : uti,
                        @"utis" : itemProvider.registeredTypeIdentifiers,
//                        @"name" : [writableUrl lastPathComponent],
//                        @"type" : mimeType,
                        @"processed": @YES,
                        //                                          @"qrString": qrString,
                    };
                    NSMutableDictionary *dict = [NSMutableDictionary  new];
                    [dict addEntriesFromDictionary:_dict];
                    if (self.contentText){
                        [dict setValue:self.contentText forKey:@"text"];
                    }

//                    NSString *qrString = nil;
//
//                    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{ CIDetectorAccuracy : CIDetectorAccuracyHigh }];
//
//                    NSArray *features = [detector featuresInImage: [CIImage imageWithCGImage: image.CGImage]];
                    
                    NSString *suggestedName=[@"shared_image_" stringByAppendingFormat:@"%d", numUnnamedImage];// stringByAppendingString:@".JPG"];

                    [self saveImage:suggestedName image:image dict:dict];

                
                    
                    [items addObject:dict];
                    if (remainingAttachments == 0) {
                        [self sendResults:results];
                    }
                    
                    
                }
                //
                //            }];
                //
                //            [itemProvider loadItemForTypeIdentifier:@"public.image" options:nil completionHandler: ^(NSURL *item, NSError *error) {
                
                NSLog(@"[ShareViewController.m: error check 2:]%@", error);
                
                
                //                NSData *data = [NSData dataWithContentsOfURL:(NSURL*)item];
                
                //                NSString *base64 = [data convertToBase64];
                
                
                
                
                //                NSString *qrString = nil;
                
        
                //                UIImage *image =    [UIImage imageWithData: data];
                
                
                //                NSString *writablePath = [documentsDirectoryPath stringByAppendingPathComponent:suggestedName];
                
                
                
                
                //                [fileManager copyItemAtURL: item toURL:writableUrl error: NULL];
                
                //                [data writeToFile:writablePath atomically:true];
                
                //                [self debug:[NSString stringWithFormat:@"item provider = %CGSIZE", [image size]]];
                //                NSData *reducedData = UIImageJPEGRepresentation(image, 0.1);
                //                base64 = [reducedData convertToBase64];
                
                
                
                
                //                CIImage *cgImage = [CIImage imageWithCGImage: image.CGImage];
                
                
                
                //                NSArray *features = [detector featuresInImage: cgImage];//[CIImage imageWithCGImage: image.CGImage]];
                
                //                if (features.count>0){
                //                    CIQRCodeFeature *feature = [features objectAtIndex:0];
                //                    qrString = feature.messageString;
                //                }
                
                //                NSString *fileUrl = [writableUrl absoluteURL].absoluteString;
                //
                //                NSDictionary *_dict = @{
                //                    //                                          @"text" : self.contentText,
                //                    @"url" : fileUrl,//writablePath,//url,
                //                    @"uti"  : uti,
                //                    @"utis" : itemProvider.registeredTypeIdentifiers,
                //                    @"name" : [writableUrl lastPathComponent],
                //                    @"type" : mimeType,
                //                    @"processed": @YES,
                //                    //                                          @"qrString": qrString,
                //                };
                //                NSMutableDictionary *dict = [NSMutableDictionary  new];
                //                [dict addEntriesFromDictionary:_dict];
                //
                //                if (qrString){
                //                    [dict setValue:qrString forKey:@"qrString"];
                //                }
                //
                //                if (self.contentText){
                //                    [dict setValue:self.contentText forKey:@"text"];
                //                }
                //
                //
                //
                //                [items addObject:dict];
                //                if (remainingAttachments == 0) {
                //                    [self sendResults:results];
                //                }
            }
        ];
        }
        else if ([itemProvider hasItemConformingToTypeIdentifier:@"public.url"]) {
            __block NSString *content = nil;
            //            __block NSString *qrString = nil;
            //            __block NSString *base64=nil;
            [itemProvider loadItemForTypeIdentifier:@"public.url" options:nil completionHandler: ^(NSData* data, NSError *error) {
                content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                
            }];
            //            [itemProvider loadPreviewImageWithOptions:nil completionHandler:^(UIImage * item, NSError * _Null_unspecified error) {
            ////                [itemProvider loadPreviewImageWithOptions:@{NSItemProviderPreferredImageSizeKey: [NSValue valueWithCGSize:CGSizeMake(self.view.frame.size.width, self.view.frame.size.height)]} completionHandler:^(UIImage * item, NSError * _Null_unspecified error) {
            ////                    [itemProvider loadPreviewImageWithOptions:@{NSItemProviderPreferredImageSizeKey: [NSValue valueWithCGSize:CGSizeMake(200.0, 100.0)]} completionHandler:^(UIImage * item, NSError * _Null_unspecified error) {
            //
            //
            //
            //                CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{ CIDetectorAccuracy : CIDetectorAccuracyHigh }];
            //
            //                NSArray *features = [detector featuresInImage:[CIImage imageWithCGImage: item.CGImage]];
            //
            //
            //                if (features.count>0){
            //                    CIQRCodeFeature *feature = [features objectAtIndex:0];
            //                    qrString = feature.messageString;
            //                };
            //
            //                                NSData *data = UIImagePNGRepresentation(item);
            //
            //                                base64 = [data convertToBase64];
            //
            //
            //                        // Set the size to that desired, however,
            //                        // Note that the image 'item' returns will not necessarily by the size that you requested, so code should handle that case.
            //                        // Use the UIImage however you wish here.
            //            }];
            [itemProvider loadItemForTypeIdentifier:@"public.url" options:nil completionHandler: ^(NSURL* item, NSError *error) {
                --remainingAttachments;
                
                
                //                NSData *data = [NSData dataWithContentsOfURL:(NSURL*)item];
                //                NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                
                NSString *url = [item absoluteURL].absoluteString;
                NSLog(@"[ShareViewController.m]%@", url);
                
                [self debug:[NSString stringWithFormat:@"public.url = %@", item]];
                NSString *uti = @"public.url";
                NSDictionary *dict = nil;
                //                if (qrString){
                //                    dict = @{
                //                                           @"uti": uti,
                //                                           @"utis": itemProvider.registeredTypeIdentifiers,
                //                                           @"name": @"",
                //                                           @"content": content,
                //                                           @"base64": base64,
                //                                           @"imageType": @"image/png",
                //                                           @"qrString": qrString,
                //                                           @"url": url,
                //                                           @"type": [self mimeTypeFromUti:uti],
                //                                      };
                //                }
                //                else {
                    dict = @{
                                               @"uti": uti,
                                               @"utis": itemProvider.registeredTypeIdentifiers,
                                               @"name": @"",
                                               @"content": content,
                    //                                               @"base64": base64,
                                               @"imageType": @"image/png",
                                               @"url": url,
                                               @"type": [self mimeTypeFromUti:uti],
                                          };
                
                //                }
                [items addObject:dict];
                if (remainingAttachments == 0) {
                    [self sendResults:results];
                }
            }];
        }
        // TEXT case
        else if ([itemProvider hasItemConformingToTypeIdentifier:@"public.text"]) {
            [itemProvider loadItemForTypeIdentifier:@"public.text" options:nil completionHandler: ^(NSString* item, NSError *error) {
                --remainingAttachments;
                [self debug:[NSString stringWithFormat:@"public.text = %@", item]];
                NSString *uti = @"public.text";
                NSDictionary *dict = @{
                                           @"text" : self.contentText,
                                           @"data" : item,
                                           @"uti": uti,
                                           @"utis": itemProvider.registeredTypeIdentifiers,
                                           @"name": @"",
                                           @"type": [self mimeTypeFromUti:uti],
                                       };
                [items addObject:dict];
                if (remainingAttachments == 0) {
                    [self sendResults:results];
                }
            }];
        }
        else {
            [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
        }
    }
    
}

- (void) sendResults: (NSDictionary*)results {
    [self.userDefaults setValue: results forKey:@"shared"];
    [self.userDefaults synchronize];
    
    // Emit a URL that opens the cordova app
    NSString *url = [NSString stringWithFormat:@"%@://shared", SHAREEXT_URL_SCHEME];
    
    //    [self.extensionContext completeRequestReturningItems:@[] completionHandler:^(BOOL result){
    //        [self openURL:[NSURL URLWithString:url]];
    //    }];
    
    [self openURL:[NSURL URLWithString:url]];
    
    
    //need to sleep to avoid thread lock. -tanli
    usleep(1000000);
    
    // Shut down the extension
    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
    
}


- (NSArray*) configurationItems {
    // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
    return @[];
}

- (NSString*) backURLFromBundleID: (NSString*)bundleId {
    if (bundleId == nil) return nil;
    // App Store - com.apple.AppStore
    if ([bundleId isEqualToString:@"com.apple.AppStore"]) return @"itms-apps://";
    // Calculator - com.apple.calculator
    // Calendar - com.apple.mobilecal
    // Camera - com.apple.camera
    // Clock - com.apple.mobiletimer
    // Compass - com.apple.compass
    // Contacts - com.apple.MobileAddressBook
    // FaceTime - com.apple.facetime
    // Find Friends - com.apple.mobileme.fmf1
    // Find iPhone - com.apple.mobileme.fmip1
    // Game Center - com.apple.gamecenter
    // Health - com.apple.Health
    // iBooks - com.apple.iBooks
    // iTunes Store - com.apple.MobileStore
    // Mail - com.apple.mobilemail - message://
    if ([bundleId isEqualToString:@"com.apple.mobilemail"]) return @"message://";
    // Maps - com.apple.Maps - maps://
    if ([bundleId isEqualToString:@"com.apple.Maps"]) return @"maps://";
    // Messages - com.apple.MobileSMS
    // Music - com.apple.Music
    // News - com.apple.news - applenews://
    if ([bundleId isEqualToString:@"com.apple.news"]) return @"applenews://";
    // Notes - com.apple.mobilenotes - mobilenotes://
    if ([bundleId isEqualToString:@"com.apple.mobilenotes"]) return @"mobilenotes://";
    // Phone - com.apple.mobilephone
    // Photos - com.apple.mobileslideshow
    if ([bundleId isEqualToString:@"com.apple.mobileslideshow"]) return @"photos-redirect://";
    // Podcasts - com.apple.podcasts
    // Reminders - com.apple.reminders - x-apple-reminder://
    if ([bundleId isEqualToString:@"com.apple.reminders"]) return @"x-apple-reminder://";
    // Safari - com.apple.mobilesafari
    // Settings - com.apple.Preferences
    // Stocks - com.apple.stocks
    // Tips - com.apple.tips
    // Videos - com.apple.videos - videos://
    if ([bundleId isEqualToString:@"com.apple.videos"]) return @"videos://";
    // Voice Memos - com.apple.VoiceMemos - voicememos://
    if ([bundleId isEqualToString:@"com.apple.VoiceMemos"]) return @"voicememos://";
    // Wallet - com.apple.Passbook
    // Watch - com.apple.Bridge
    // Weather - com.apple.weather
    return nil;
}

// This is called at the point where the Post dialog is about to be shown.
// We use it to store the _hostBundleID
- (void) willMoveToParentViewController: (UIViewController*)parent {
    NSString *hostBundleID = [parent valueForKey:(@"_hostBundleID")];
    self.backURL = [self backURLFromBundleID:hostBundleID];
}


- (NSString *)mimeTypeFromUti: (NSString*)uti {
    if (uti == nil) {
        return nil;
    }
    CFStringRef cret = UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)uti, kUTTagClassMIMEType);
    NSString *ret = (__bridge_transfer NSString *)cret;
    return ret == nil ? uti : ret;
}

@end
