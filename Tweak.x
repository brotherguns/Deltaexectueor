#import <Foundation/Foundation.h>
#import <substrate.h>

// Delta Key Bypass - Fox
// Target: Any iOS App using NSURLSession for key validation

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    
    NSString *url = request.URL.absoluteString;
    
    // Catching the key validation endpoint. 
    // You might need to sniff the exact domain using Charles Proxy if they update it, 
    // but looking for "delta" or "key" usually catches it.
    if ([url localizedCaseInsensitiveContainsString:@"delta"] || 
        [url localizedCaseInsensitiveContainsString:@"key"] || 
        [url localizedCaseInsensitiveContainsString:@"gateway"]) {


        NSLog(@"[*] Fox: Intercepted and nuked Delta key request to %@", url);
        
        // 1. Forge the HTTP 200 OK Response
        NSHTTPURLResponse *fakeResponse = [[NSHTTPURLResponse alloc] 
                                           initWithURL:request.URL 
                                           statusCode:200 
                                           HTTPVersion:@"HTTP/1.1" 
                                           headerFields:@{@"Content-Type": @"application/json"}];
        
        // 2. Forge the JSON payload. 
        // Most of these cheap key systems just look for a positive boolean or success status.
        NSString *fakeJson = @"{\"status\":\"success\", \"valid\":true, \"premium\":true, \"message\":\"Bypassed\"}";
        NSData *fakeData = [fakeJson dataUsingEncoding:NSUTF8StringEncoding];
        
        // 3. Fire the app's original callback block with our fake data
        if (completionHandler) {
            completionHandler(fakeData, fakeResponse, nil);
        }
        
        // 4. Return nil so the real network request is never actually executed
        return nil;
    }
    
    // If it's normal Roblox traffic (loading games, assets), let it pass normally
    return %orig(request, completionHandler);
}

%end
