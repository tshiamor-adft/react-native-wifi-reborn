#import "RNWifi.h"
#import <NetworkExtension/NetworkExtension.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>


@interface WifiManager () <CLLocationManagerDelegate>
@property (nonatomic,strong) CLLocationManager *locationManager;
@property (nonatomic) BOOL solved;
@end
@implementation WifiManager

- (instancetype)init {
  self = [super init];
  if (self) {
      NSLog(@"RNWIFI:Init");
      self.solved = YES;
          if (@available(iOS 13, *)) {
              self.locationManager = [[CLLocationManager alloc] init];
              self.locationManager.delegate = self;
          }
  }
  return self;
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    NSLog(@"RNWIFI:statechaged %d", status);
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"RNWIFI:authorizationStatus" object:nil userInfo:nil];
}

- (NSString *) getWifiSSID {
    NSString *kSSID = (NSString*) kCNNetworkInfoKeySSID;

    NSArray *ifs = (__bridge_transfer id)CNCopySupportedInterfaces();
    for (NSString *ifnam in ifs) {
        NSDictionary *info = (__bridge_transfer id)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam);
        if (info[kSSID]) {
            return info[kSSID];
        }
    }
    return nil;
}

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(connectToSSID:(NSString*)ssid
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    if (@available(iOS 11.0, *)) {
        NEHotspotConfiguration* configuration = [[NEHotspotConfiguration alloc] initWithSSID:ssid];
        configuration.joinOnce = false://true; mod

        [[NEHotspotConfigurationManager sharedManager] applyConfiguration:configuration completionHandler:^(NSError * _Nullable error) {
            if (error != nil) {
                reject(@"nehotspot_error", @"Error while configuring WiFi", error);
            } else {
                resolve(nil);
            }
        }];

    } else {
        reject(@"ios_error", @"Not supported in iOS<11.0", nil);
    }
}

RCT_EXPORT_METHOD(connectToProtectedSSID:(NSString*)ssid
                  withPassphrase:(NSString*)passphrase
                  isWEP:(BOOL)isWEP
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    if (@available(iOS 11.0, *)) {
        NEHotspotConfiguration* configuration = [[NEHotspotConfiguration alloc] initWithSSID:ssid passphrase:passphrase isWEP:isWEP];
        configuration.joinOnce = false://true; mod

        [[NEHotspotConfigurationManager sharedManager] applyConfiguration:configuration completionHandler:^(NSError * _Nullable error) {
            if (error != nil) {
                reject(@"nehotspot_error", @"Error while configuring WiFi", error);
            } else {
                resolve(nil);
            }
        }];

    } else {
        reject(@"ios_error", @"Not supported in iOS<11.0", nil);
    }
}

RCT_EXPORT_METHOD(disconnectFromSSID:(NSString*)ssid
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    if (@available(iOS 11.0, *)) {
        [[NEHotspotConfigurationManager sharedManager] getConfiguredSSIDsWithCompletionHandler:^(NSArray<NSString *> *ssids) {
            if (ssids != nil && [ssids indexOfObject:ssid] != NSNotFound) {
                [[NEHotspotConfigurationManager sharedManager] removeConfigurationForSSID:ssid];
            }
            resolve(nil);
        }];
    } else {
        reject(@"ios_error", @"Not supported in iOS<11.0", nil);
    }

}


RCT_REMAP_METHOD(getCurrentWifiSSID,
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {

    if (@available(iOS 13, *)) {
        // Reject when permission had rejected
        if([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied){
            NSLog(@"RNWIFI:ERROR:Cannot detect SSID because LocationPermission is Denied ");
            reject(@"cannot_detect_ssid", @"Cannot detect SSID because LocationPermission is Denied", nil);
        }
        if([CLLocationManager authorizationStatus] == kCLAuthorizationStatusRestricted){
            NSLog(@"RNWIFI:ERROR:Cannot detect SSID because LocationPermission is Restricted ");
            reject(@"cannot_detect_ssid", @"Cannot detect SSID because LocationPermission is Restricted", nil);
        }
    }

    BOOL hasLocationPermission = [CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedWhenInUse ||
    [CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways;
    if (@available(iOS 13, *) && hasLocationPermission == NO) {
        // Need request LocationPermission or HotSpot or have VPN connection
        // https://forums.developer.apple.com/thread/117371#364495
        [self.locationManager requestWhenInUseAuthorization];
        self.solved = NO;
        [[NSNotificationCenter defaultCenter] addObserverForName:@"RNWIFI:authorizationStatus" object:nil queue:nil usingBlock:^(NSNotification *note)
        {
            if(self.solved == NO){
                if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedWhenInUse ||
                    [CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways){
                    NSString *SSID = [self getWifiSSID];
                    if (SSID){
                        resolve(SSID);
                        return;
                    }
                    NSLog(@"RNWIFI:ERROR:Cannot detect SSID");
                    reject(@"cannot_detect_ssid", @"Cannot detect SSID", nil);
                }else{
                    reject(@"ios_error", @"Permission not granted", nil);
                }
            }
            // Avoid call when live-reloaded app
            self.solved = YES;
        }];
    }else{
        NSString *SSID = [self getWifiSSID];
        if (SSID){
            resolve(SSID);
            return;
        }
        NSLog(@"RNWIFI:ERROR:Cannot detect SSID");
        reject(@"cannot_detect_ssid", @"Cannot detect SSID", nil);
    }
}

- (NSDictionary*)constantsToExport {
    // Officially better to use UIApplicationOpenSettingsURLString
    return @{
             @"settingsURL": UIApplicationOpenSettingsURLString
             };
}

@end
