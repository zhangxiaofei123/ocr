//
//  ViewController.m
//  AipOcrDemo
//
//  Created by chenxiaoyu on 17/2/7.
//  Copyright © 2017年 baidu. All rights reserved.
//

#import "ViewController.h"
#import <objc/runtime.h>
#import <AipOcrSdk/AipOcrSdk.h>
#import "SVProgressHUD.h"
#import "iCloudManager.h"
#import <TZImagePickerController/TZImagePickerController.h>

#import "Reachability.h"

@interface ViewController ()<UIAlertViewDelegate,UIDocumentPickerDelegate,UIDocumentInteractionControllerDelegate,TZImagePickerControllerDelegate>

@property(nonatomic,strong) NSMutableArray *imageArray;
@property(nonatomic,strong) NSString *filePath;
@property(nonatomic,strong) NSString *fileName;
@property(nonatomic,strong) NSMutableString *message;
@property (nonatomic, strong) UIDocumentInteractionController *documentIc;
@property (weak, nonatomic) IBOutlet UIButton *selectButton;
@property (weak, nonatomic) IBOutlet UIButton *shareButton;
@property (weak, nonatomic) IBOutlet UIButton *transButton;
@property (nonatomic) Reachability *hostReachability;
@property (nonatomic) Reachability *internetReachability;
@property (nonatomic, strong) NSMutableArray<NSArray<NSString *> *> *actionList;

@end

@implementation ViewController {
    // 默认的识别成功的回调
    void (^_successHandler)(id);
    // 默认的识别失败的回调
    void (^_failHandler)(NSError *);
}

/// 当网络状态发生变化时调用
- (void)appReachabilityChanged:(NSNotification *)notification{
    Reachability *reach = [notification object];
    if([reach isKindOfClass:[Reachability class]]){
        NetworkStatus status = [reach currentReachabilityStatus];
        // 两种检测:路由与服务器是否可达  三种状态:手机流量联网、WiFi联网、没有联网
        if (reach == self.internetReachability) {
            if (status == NotReachable) {
                NSLog(@"internetReachability NotReachable");
            } else if (status == ReachableViaWiFi) {
                NSLog(@"internetReachability ReachableViaWiFi");
            } else if (status == ReachableViaWWAN) {
                NSLog(@"internetReachability ReachableViaWWAN");
            }
        }
        if (reach == self.hostReachability) {
            NSLog(@"hostReachability");
            if ([reach currentReachabilityStatus] == NotReachable) {
                NSLog(@"hostReachability failed");
                [[[UIAlertView alloc] initWithTitle:@"未链接网络" message:@"请先打开网络链接" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil] show];
            } else if (status == ReachableViaWiFi) {
                NSLog(@"hostReachability ReachableViaWiFi");
            } else if (status == ReachableViaWWAN) {
                NSLog(@"hostReachability ReachableViaWWAN");
            }
        }
        
    }
}
/// 取消通知
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Reachability使用了通知，当网络状态发生变化时发送通知kReachabilityChangedNotification
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appReachabilityChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    // 检测指定服务器是否可达
    NSString *remoteHostName = @"www.bing.com";
    self.hostReachability = [Reachability reachabilityWithHostName:remoteHostName];
    [self.hostReachability startNotifier];
    // 检测默认路由是否可达
    self.internetReachability = [Reachability reachabilityForInternetConnection];
    [self.internetReachability startNotifier];
    
    
    _imageArray = [NSMutableArray new];
    
    //    #error 【必须！】请在 ai.baidu.com中新建App, 绑定BundleId后，在此填写授权信息
    //    #error 【必须！】上传至AppStore前，请使用lipo移除AipBase.framework、AipOcrSdk.framework的模拟器架构，参考FAQ：ai.baidu.com/docs#/OCR-iOS-SDK/top
    //     授权方法1：在此处填写App的Api Key/Secret Key
    [[AipOcrService shardService] authWithAK:@"RVdghwSrRD9LpaR49TEmUlGo" andSK:@"8GIgnt196PwxyvbMhFw4WSmkd5esvsXu"];
    
    
    // 授权方法2（更安全）： 下载授权文件，添加至资源
    NSString *licenseFile = [[NSBundle mainBundle] pathForResource:@"aip" ofType:@"license"];
    NSData *licenseFileData = [NSData dataWithContentsOfFile:licenseFile];
    if(!licenseFileData) {
        [[[UIAlertView alloc] initWithTitle:@"授权失败" message:@"授权文件不存在" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil] show];
    }
    [[AipOcrService shardService] authWithLicenseFileData:licenseFileData];
    
    
    [self configureView];
    [self configureData];
    [self configCallback];
}


//遍历所有.m文件
- (void)showAllFileWithPath:(NSString *) path {
    NSFileManager * fileManger = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL isExist = [fileManger fileExistsAtPath:path isDirectory:&isDir];
    if (isExist) {
        if (isDir) {
            NSArray * dirArray = [fileManger contentsOfDirectoryAtPath:path error:nil];
            NSString * subPath = nil;
            for (NSString * str in dirArray) {
                subPath  = [path stringByAppendingPathComponent:str];
                BOOL issubDir = NO;
                [fileManger fileExistsAtPath:subPath isDirectory:&issubDir];
                [self showAllFileWithPath:subPath];
            }
        }else{
            NSString *fileName = [[path componentsSeparatedByString:@"/"] lastObject];
            if ([fileName hasSuffix:@".png"]) {
                NSRange range1;
                range1 = [fileName rangeOfString:@"_"];
                if (range1.location != NSNotFound) {
                    NSLog(@"found at location = %lu, length = %lu",(unsigned long)range1.location,(unsigned long)range1.length);
                    NSString *ok = [fileName substringFromIndex:range1.location + 1 ];
                    //                    NSLog(@"%@",ok);
                    NSRange range2;
                    range2 = [ok rangeOfString:@"."];
                    if (range2.location != NSNotFound) {
                        NSLog(@"found at location = %lu, length = %lu",(unsigned long)range2.location,(unsigned long)range2.length);
                        NSString *oks = [ok substringToIndex:range2.location];
                        NSLog(@"%@",oks);
                        int intString = [oks intValue];
                        
                        [_imageArray addObject:[NSNumber numberWithInt:intString]];
                        
                    }else{
                        NSLog(@"Not Found");
                    }
                }else{
                    NSLog(@"Not Found");
                }
            }
        }
    }else{
        NSLog(@"this path is not exist!");
    }
    
}

#pragma mark - UIDocumentPickerDelegate
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url {
    NSArray *array = [[url absoluteString] componentsSeparatedByString:@"/"];
    NSString *fileName = [array lastObject];
    fileName = [fileName stringByRemovingPercentEncoding];
    NSLog(@"--->>>>%@",fileName);
    //            写入沙盒Documents
    [_selectButton setTitle:fileName forState:UIControlStateNormal];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = [paths objectAtIndex:0];
    
    NSString *path = [documentsDir stringByAppendingString:[NSString stringWithFormat:@"/%@",fileName]];
    if ([iCloudManager iCloudEnable]) {
        [iCloudManager downloadWithDocumentURL:url callBack:^(id obj) {
            NSData *data = obj;
            [data writeToFile:path atomically:YES];
            
            NSURL *urlMovie = [NSURL fileURLWithPath:path];
            CGPDFDocumentRef fromPDFDoc = CGPDFDocumentCreateWithURL((CFURLRef) urlMovie);
            
            // Get Total Pages
            int pages = CGPDFDocumentGetNumberOfPages(fromPDFDoc);
            
            // Create Folder for store under "Documents/"
            NSError *error = nil;
            NSFileManager *fileManager = [[NSFileManager alloc] init];
            NSString *folderPath = [documentsDir stringByAppendingPathComponent:[fileName stringByDeletingPathExtension]];
            _filePath = folderPath;
            
            [fileManager createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:&error];
            
            int i = 1;
            for (i = 1; i <= pages; i++) {
                CGPDFPageRef pageRef = CGPDFDocumentGetPage(fromPDFDoc, i);
                CGPDFPageRetain(pageRef);
                
                // determine the size of the PDF page
                CGRect pageRect = CGPDFPageGetBoxRect(pageRef, kCGPDFMediaBox);
                
                // renders its content.
                UIGraphicsBeginImageContext(pageRect.size);
                
                CGContextRef imgContext = UIGraphicsGetCurrentContext();
                CGContextSetRGBFillColor(imgContext, 1.0,1.0,1.0,1.0);
                CGContextSetShouldAntialias(imgContext, YES);
                CGContextSetAllowsAntialiasing(imgContext, YES);
                CGContextSaveGState(imgContext);
                CGContextTranslateCTM(imgContext, 0.0, pageRect.size.height);
                CGContextScaleCTM(imgContext, 1.0, -1.0);
                CGContextSetInterpolationQuality(imgContext, kCGInterpolationHigh);
                CGContextSetRenderingIntent(imgContext, kCGRenderingIntentPerceptual);
                CGContextDrawPDFPage(imgContext, pageRef);
                CGContextRestoreGState(imgContext);
                
                //PDF Page to image
                UIImage *tempImage = UIGraphicsGetImageFromCurrentImageContext();
                
                UIGraphicsEndImageContext();
                //Release current source page
                CGPDFPageRelease(pageRef);
                
                // Store IMG
                NSString *imgname = [NSString stringWithFormat:@"_%d.png", i];
                NSString *imgPath = [folderPath stringByAppendingPathComponent:imgname];
                [UIImagePNGRepresentation(tempImage) writeToFile:imgPath atomically:YES];
                
            }
            CGPDFDocumentRelease(fromPDFDoc);
            [self trans];
        }];
    }
    
    
}

-(void)delete{
    NSString *DocumentsPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:DocumentsPath];
    for (NSString *fileName in enumerator) {
        [[NSFileManager defaultManager] removeItemAtPath:[DocumentsPath stringByAppendingPathComponent:fileName] error:nil];
    }
}
- (IBAction)selectDocument:(UIButton *)sender {
    [self delete];
    sender.userInteractionEnabled = NO;
    //    NSArray *documentTypes = @[@"public.content", @"public.text", @"public.source-code ", @"public.image", @"public.audiovisual-content", @"com.adobe.pdf", @"com.apple.keynote.key", @"com.microsoft.word.doc", @"com.microsoft.excel.xls", @"com.microsoft.powerpoint.ppt"];
    NSArray *documentTypes = @[@"com.adobe.pdf"];
    UIDocumentPickerViewController *documentPickerViewController = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:documentTypes inMode:UIDocumentPickerModeOpen];
    documentPickerViewController.delegate = self;
    [self presentViewController:documentPickerViewController animated:YES completion:nil];
}

-(void)trans {
    _message = [NSMutableString string];
    
    [self showAllFileWithPath:_filePath];
    NSArray *result = [_imageArray sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
    
    NSString *load = [NSString stringWithFormat:@"正在识别。。。"];
    [SVProgressHUD showWithStatus:load];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        for (int i =1; i <= _imageArray.count; i ++) {
            
            dispatch_semaphore_t sem = dispatch_semaphore_create(0);
            NSString *imageName = [NSString stringWithFormat:@"_%d.png",i];
            NSString *imagePath=[_filePath stringByAppendingPathComponent:imageName];
            UIImage *image=[UIImage imageWithContentsOfFile:imagePath];
            
            NSDictionary *options = @{@"language_type": @"CHN_ENG", @"detect_direction": @"true"};
            [[AipOcrService shardService] detectTextBasicFromImage:image withOptions:options successHandler:^(id result) {
                if(result[@"words_result"]){
                    if([result[@"words_result"] isKindOfClass:[NSDictionary class]]){
                        [result[@"words_result"] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                            if([obj isKindOfClass:[NSDictionary class]] && [obj objectForKey:@"words"]){
                                [_message appendFormat:@"%@: %@\n", key, obj[@"words"]];
                            }else{
                                [_message appendFormat:@"%@: %@\n", key, obj];
                            }
                            
                        }];
                    }else if([result[@"words_result"] isKindOfClass:[NSArray class]]){
                        for(NSDictionary *obj in result[@"words_result"]){
                            if([obj isKindOfClass:[NSDictionary class]] && [obj objectForKey:@"words"]){
                                [_message appendFormat:@"%@\n", obj[@"words"]];
                            }else{
                                [_message appendFormat:@"%@\n", obj];
                            }
                            
                        }
                    }
                    dispatch_semaphore_signal(sem);
                }
            } failHandler:^(NSError *err) {
                NSString *msg = [NSString stringWithFormat:@"%li:%@", (long)[err code], [err localizedDescription]];
                NSLog(@"error = %@", msg);
            }];
            dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
        }
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [SVProgressHUD dismiss];
            [_selectButton setTitle:@"PDF选择" forState:UIControlStateNormal];
            _selectButton.userInteractionEnabled = YES;
            _shareButton.userInteractionEnabled = YES;
            
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"完成" message:_message delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil];
            [alertView show];
        }];
        NSLog(@"message = %@", _message);
    });
    
}
- (IBAction)mutiTrans:(id)sender {
    _message = [NSMutableString string];
    
    TZImagePickerController *vc = [[TZImagePickerController alloc] initWithMaxImagesCount:9 delegate:self];
    
    // You can get the photos by block, the same as by delegate.
    // 你可以通过block或者代理，来得到用户选择的照片.
    [vc setDidFinishPickingPhotosHandle:^(NSArray<UIImage *> *photos, NSArray *assets,BOOL isSelectOriginalPhoto) {
        
        NSString *load = [NSString stringWithFormat:@"正在识别。。。"];
        [SVProgressHUD showWithStatus:load];
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            
            for (int i =1; i <= photos.count; i ++) {
                
                dispatch_semaphore_t sem = dispatch_semaphore_create(0);
                
                NSDictionary *options = @{@"language_type": @"CHN_ENG", @"detect_direction": @"true"};
                
                UIImage *image = photos[i-1];
                [[AipOcrService shardService] detectTextBasicFromImage:image withOptions:options successHandler:^(id result) {
                    if(result[@"words_result"]){
                        if([result[@"words_result"] isKindOfClass:[NSDictionary class]]){
                            [result[@"words_result"] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                                if([obj isKindOfClass:[NSDictionary class]] && [obj objectForKey:@"words"]){
                                    [_message appendFormat:@"%@: %@\n", key, obj[@"words"]];
                                }else{
                                    [_message appendFormat:@"%@: %@\n", key, obj];
                                }
                                
                            }];
                        }else if([result[@"words_result"] isKindOfClass:[NSArray class]]){
                            for(NSDictionary *obj in result[@"words_result"]){
                                if([obj isKindOfClass:[NSDictionary class]] && [obj objectForKey:@"words"]){
                                    [_message appendFormat:@"%@\n", obj[@"words"]];
                                }else{
                                    [_message appendFormat:@"%@\n", obj];
                                }
                                
                            }
                        }
                        dispatch_semaphore_signal(sem);
                    }
                } failHandler:^(NSError *err) {
                    NSString *msg = [NSString stringWithFormat:@"%li:%@", (long)[err code], [err localizedDescription]];
                    NSLog(@"error = %@", msg);
                }];
                dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
            }
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [SVProgressHUD dismiss];
                _shareButton.userInteractionEnabled = YES;
                
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"完成" message:_message delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil];
                [alertView show];
            }];
            NSLog(@"message = %@", _message);
        });
        
    }];
    [self presentViewController:vc animated:YES completion:nil];
}
- (IBAction)trans:(UIButton *)sender {
    [self delete];
    _message = [NSMutableString string];
    
    UIViewController * vc = [AipGeneralVC ViewControllerWithHandler:^(UIImage *image) {
        NSString *load = [NSString stringWithFormat:@"正在识别。。。"];
        [SVProgressHUD showWithStatus:load];
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            dispatch_semaphore_t sem = dispatch_semaphore_create(0);
            
            NSDictionary *options = @{@"language_type": @"CHN_ENG", @"detect_direction": @"true"};
            [[AipOcrService shardService] detectTextBasicFromImage:image withOptions:options successHandler:^(id result) {
                if(result[@"words_result"]){
                    if([result[@"words_result"] isKindOfClass:[NSDictionary class]]){
                        [result[@"words_result"] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                            if([obj isKindOfClass:[NSDictionary class]] && [obj objectForKey:@"words"]){
                                [_message appendFormat:@"%@: %@\n", key, obj[@"words"]];
                            }else{
                                [_message appendFormat:@"%@: %@\n", key, obj];
                            }
                            
                        }];
                    }else if([result[@"words_result"] isKindOfClass:[NSArray class]]){
                        for(NSDictionary *obj in result[@"words_result"]){
                            if([obj isKindOfClass:[NSDictionary class]] && [obj objectForKey:@"words"]){
                                [_message appendFormat:@"%@\n", obj[@"words"]];
                            }else{
                                [_message appendFormat:@"%@\n", obj];
                            }
                            
                        }
                    }
                    NSLog(@"message = %@", _message);
                    dispatch_semaphore_signal(sem);
                    
                }
            } failHandler:^(NSError *err) {
                NSString *msg = [NSString stringWithFormat:@"%li:%@", (long)[err code], [err localizedDescription]];
                NSLog(@"error = %@", msg);
            }];
            
            dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
            [SVProgressHUD dismiss];
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                _shareButton.userInteractionEnabled = YES;
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"完成" message:_message delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil];
                [alertView show];
            }];
        });
    }];
    
    [self presentViewController:vc animated:YES completion:nil];
    
}


- (IBAction)share:(UIButton *)sender {
    
    if ([_message length] == 0) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"完成" message:@"未检测到文字" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alertView show];
        return;
    }
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = [paths objectAtIndex:0];
    NSString *path=[documentsDir stringByAppendingPathComponent:@"/zxf.txt"];
    //    NSString *str = @"123123123这是一个导出的字符串";
    //文件不存在会自动创建，文件夹不存在则不会自动创建会报错
    NSError *error;
    [_message writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"导出失败:%@",error);
    }else{
        NSLog(@"导出成功");
        // 调用safari分享功能将文件分享出去
        UIDocumentInteractionController *documentIc = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:path]];
        
        // 记得要强引用UIDocumentInteractionController,否则控制器释放后再次点击分享程序会崩溃
        self.documentIc = documentIc;
        
        // 如果需要其他safari分享的更多交互,可以设置代理
        documentIc.delegate = self;
        
        // 设置分享显示的矩形框
        CGRect rect = CGRectMake(0, 0, self.view.frame.size.width, 300);
        [documentIc presentOpenInMenuFromRect:rect inView:self.view animated:YES];
        [documentIc presentPreviewAnimated:YES];
    }
}





- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)configureView {
    
    self.title = @"文字识别";
}

- (void)configureData {
    
    self.actionList = [NSMutableArray array];
    
    [self.actionList addObject:@[@"通用文字识别", @"generalBasicOCR"]];
    //    [self.actionList addObject:@[@"通用文字识别(高精度版)", @"generalAccurateBasicOCR"]];
    //    [self.actionList addObject:@[@"通用文字识别(含位置信息版)", @"generalOCR"]];
    //    [self.actionList addObject:@[@"通用文字识别(高精度含位置版)", @"generalAccurateOCR"]];
    //    [self.actionList addObject:@[@"通用文字识别(含生僻字版)", @"generalEnchancedOCR"]];
    //    [self.actionList addObject:@[@"网络图片文字识别", @"webImageOCR"]];
    //    [self.actionList addObject:@[@"身份证正面拍照识别", @"idcardOCROnlineFront"]];
    //    [self.actionList addObject:@[@"身份证反面拍照识别", @"idcardOCROnlineBack"]];
    //    [self.actionList addObject:@[@"身份证正面(嵌入式质量控制+云端识别)", @"localIdcardOCROnlineFront"]];
    //    [self.actionList addObject:@[@"身份证反面(嵌入式质量控制+云端识别)", @"localIdcardOCROnlineBack"]];
    //    [self.actionList addObject:@[@"银行卡正面拍照识别", @"bankCardOCROnline"]];
    //    [self.actionList addObject:@[@"驾驶证识别", @"drivingLicenseOCR"]];
    //    [self.actionList addObject:@[@"行驶证识别", @"vehicleLicenseOCR"]];
    //    [self.actionList addObject:@[@"车牌识别", @"plateLicenseOCR"]];
    //    [self.actionList addObject:@[@"营业执照识别", @"businessLicenseOCR"]];
    //    [self.actionList addObject:@[@"票据识别", @"receiptOCR"]];
    //    [self.actionList addObject:@[@"自定义模板识别", @"iOCR"]];
}

- (void)configCallback {
    __weak typeof(self) weakSelf = self;
    
    // 这是默认的识别成功的回调
    _successHandler = ^(id result){
        NSLog(@"%@", result);
        NSString *title = @"识别结果";
        NSMutableString *message = [NSMutableString string];
        
        if(result[@"words_result"]){
            if([result[@"words_result"] isKindOfClass:[NSDictionary class]]){
                [result[@"words_result"] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                    if([obj isKindOfClass:[NSDictionary class]] && [obj objectForKey:@"words"]){
                        [message appendFormat:@"%@: %@\n", key, obj[@"words"]];
                    }else{
                        [message appendFormat:@"%@: %@\n", key, obj];
                    }
                    
                }];
            }else if([result[@"words_result"] isKindOfClass:[NSArray class]]){
                for(NSDictionary *obj in result[@"words_result"]){
                    if([obj isKindOfClass:[NSDictionary class]] && [obj objectForKey:@"words"]){
                        [message appendFormat:@"%@\n", obj[@"words"]];
                    }else{
                        [message appendFormat:@"%@\n", obj];
                    }
                    
                }
            }
            
        }else{
            [message appendFormat:@"%@", result];
        }
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:weakSelf cancelButtonTitle:@"确定" otherButtonTitles:nil];
            [alertView show];
        }];
    };
    
    _failHandler = ^(NSError *error){
        NSLog(@"%@", error);
        NSString *msg = [NSString stringWithFormat:@"%li:%@", (long)[error code], [error localizedDescription]];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [[[UIAlertView alloc] initWithTitle:@"识别失败" message:msg delegate:weakSelf cancelButtonTitle:@"确定" otherButtonTitles:nil] show];
        }];
    };
}


#pragma mark - Action
- (void)generalOCR{
    
    UIViewController * vc = [AipGeneralVC ViewControllerWithHandler:^(UIImage *image) {
        // 在这个block里，image即为切好的图片，可自行选择如何处理
        NSDictionary *options = @{@"language_type": @"CHN_ENG", @"detect_direction": @"true"};
        [[AipOcrService shardService] detectTextFromImage:image
                                              withOptions:options
                                           successHandler:_successHandler
                                              failHandler:_failHandler];
        
    }];
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)generalEnchancedOCR{
    
    UIViewController * vc = [AipGeneralVC ViewControllerWithHandler:^(UIImage *image) {
        NSDictionary *options = @{@"language_type": @"CHN_ENG", @"detect_direction": @"true"};
        [[AipOcrService shardService] detectTextEnhancedFromImage:image
                                                      withOptions:options
                                                   successHandler:_successHandler
                                                      failHandler:_failHandler];
        
    }];
    [self presentViewController:vc animated:YES completion:nil];
}



















- (void)generalAccurateOCR{
    
    UIViewController * vc = [AipGeneralVC ViewControllerWithHandler:^(UIImage *image) {
        NSDictionary *options = @{@"language_type": @"CHN_ENG", @"detect_direction": @"true"};
        [[AipOcrService shardService] detectTextAccurateFromImage:image
                                                      withOptions:options
                                                   successHandler:_successHandler
                                                      failHandler:_failHandler];
        
    }];
    [self presentViewController:vc animated:YES completion:nil];
}


- (void)generalAccurateBasicOCR{
    
    UIViewController * vc = [AipGeneralVC ViewControllerWithHandler:^(UIImage *image) {
        NSDictionary *options = @{@"language_type": @"CHN_ENG", @"detect_direction": @"true"};
        [[AipOcrService shardService] detectTextAccurateBasicFromImage:image
                                                           withOptions:options
                                                        successHandler:_successHandler
                                                           failHandler:_failHandler];
        
    }];
    [self presentViewController:vc animated:YES completion:nil];
}


- (void)webImageOCR{
    
    UIViewController * vc = [AipGeneralVC ViewControllerWithHandler:^(UIImage *image) {
        
        [[AipOcrService shardService] detectWebImageFromImage:image
                                                  withOptions:nil
                                               successHandler:_successHandler
                                                  failHandler:_failHandler];
    }];
    [self presentViewController:vc animated:YES completion:nil];
}


- (void)idcardOCROnlineFront {
    
    UIViewController * vc =
    [AipCaptureCardVC ViewControllerWithCardType:CardTypeIdCardFont
                                 andImageHandler:^(UIImage *image) {
                                     
                                     [[AipOcrService shardService] detectIdCardFrontFromImage:image
                                                                                  withOptions:nil
                                                                               successHandler:_successHandler
                                                                                  failHandler:_failHandler];
                                 }];
    
    [self presentViewController:vc animated:YES completion:nil];
    
}

- (void)localIdcardOCROnlineFront {
    
    UIViewController * vc =
    [AipCaptureCardVC ViewControllerWithCardType:CardTypeLocalIdCardFont
                                 andImageHandler:^(UIImage *image) {
                                     
                                     [[AipOcrService shardService] detectIdCardFrontFromImage:image
                                                                                  withOptions:nil
                                                                               successHandler:^(id result){
                                                                                   _successHandler(result);
                                                                                   // 这里可以存入相册
                                                                                   //UIImageWriteToSavedPhotosAlbum(image, nil, nil, (__bridge void *)self);
                                                                               }
                                                                                  failHandler:_failHandler];
                                 }];
    [self presentViewController:vc animated:YES completion:nil];
    
    
}



- (void)idcardOCROnlineBack{
    
    UIViewController * vc =
    [AipCaptureCardVC ViewControllerWithCardType:CardTypeIdCardBack
                                 andImageHandler:^(UIImage *image) {
                                     
                                     [[AipOcrService shardService] detectIdCardBackFromImage:image
                                                                                 withOptions:nil
                                                                              successHandler:_successHandler
                                                                                 failHandler:_failHandler];
                                 }];
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)localIdcardOCROnlineBack{
    
    UIViewController * vc =
    [AipCaptureCardVC ViewControllerWithCardType:CardTypeLocalIdCardBack
                                 andImageHandler:^(UIImage *image) {
                                     
                                     [[AipOcrService shardService] detectIdCardBackFromImage:image
                                                                                 withOptions:nil
                                                                              successHandler:^(id result){
                                                                                  _successHandler(result);
                                                                                  // 这里可以存入相册
                                                                                  // UIImageWriteToSavedPhotosAlbum(image, nil, nil, (__bridge void *)self);
                                                                              }
                                                                                 failHandler:_failHandler];
                                 }];
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)bankCardOCROnline{
    
    UIViewController * vc =
    [AipCaptureCardVC ViewControllerWithCardType:CardTypeBankCard
                                 andImageHandler:^(UIImage *image) {
                                     
                                     [[AipOcrService shardService] detectBankCardFromImage:image
                                                                            successHandler:_successHandler
                                                                               failHandler:_failHandler];
                                     
                                 }];
    [self presentViewController:vc animated:YES completion:nil];
    
}


- (void)drivingLicenseOCR{
    
    UIViewController * vc = [AipGeneralVC ViewControllerWithHandler:^(UIImage *image) {
        
        [[AipOcrService shardService] detectDrivingLicenseFromImage:image
                                                        withOptions:nil
                                                     successHandler:_successHandler
                                                        failHandler:_failHandler];
        
    }];
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)vehicleLicenseOCR{
    
    UIViewController * vc = [AipGeneralVC ViewControllerWithHandler:^(UIImage *image) {
        
        [[AipOcrService shardService] detectVehicleLicenseFromImage:image
                                                        withOptions:nil
                                                     successHandler:_successHandler
                                                        failHandler:_failHandler];
    }];
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)plateLicenseOCR{
    
    UIViewController * vc = [AipGeneralVC ViewControllerWithHandler:^(UIImage *image) {
        
        [[AipOcrService shardService] detectPlateNumberFromImage:image
                                                     withOptions:nil
                                                  successHandler:_successHandler
                                                     failHandler:_failHandler];
        
    }];
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)receiptOCR{
    
    UIViewController * vc = [AipGeneralVC ViewControllerWithHandler:^(UIImage *image) {
        
        [[AipOcrService shardService] detectReceiptFromImage:image
                                                 withOptions:nil
                                              successHandler:_successHandler
                                                 failHandler:_failHandler];
        
    }];
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)businessLicenseOCR{
    
    UIViewController * vc = [AipGeneralVC ViewControllerWithHandler:^(UIImage *image) {
        
        [[AipOcrService shardService] detectBusinessLicenseFromImage:image
                                                         withOptions:nil
                                                      successHandler:_successHandler
                                                         failHandler:_failHandler];
        
    }];
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)formOCR{
    
    UIViewController * vc = [AipGeneralVC ViewControllerWithHandler:^(UIImage *image) {
        
        [[AipOcrService shardService] formRecognitionFromImage:image
                                                   withOptions:nil
                                                successHandler:_successHandler
                                                   failHandler:_failHandler];
        
    }];
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)iOCR{
    
    UIViewController * vc = [AipGeneralVC ViewControllerWithHandler:^(UIImage *image) {
        
        NSDictionary *options = @{@"templateSign": @"123"};
        [[AipOcrService shardService] iOCRRecognitionFromImage:image
                                                   withOptions:options
                                                successHandler:_successHandler
                                                   failHandler:_failHandler];
        
    }];
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)mockBundlerIdForTest {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    [self mockClass:[NSBundle class] originalFunction:@selector(bundleIdentifier) swizzledFunction:@selector(sapicamera_bundleIdentifier)];
#pragma clang diagnostic pop
}

- (void)mockClass:(Class)class originalFunction:(SEL)originalSelector swizzledFunction:(SEL)swizzledSelector {
    
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
    
    BOOL didAddMethod = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
    
}

#pragma mark - UITableViewDelegate & UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return self.actionList.count;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = nil;
    
    NSArray *actions = self.actionList[indexPath.row];
    cell = [tableView dequeueReusableCellWithIdentifier:@"DemoActionCell" forIndexPath:indexPath];
    cell.textLabel.text = actions[0];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return 55;
    } else {
        return 44;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    SEL funSel = NSSelectorFromString(self.actionList[indexPath.row][1]);
    if (funSel) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:funSel];
#pragma clang diagnostic pop
    }
}

-(BOOL)shouldAutorotate{
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
