#import <Foundation/Foundation.h>

static NSString *dumpPath() {
    NSArray *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [[docs firstObject] stringByAppendingPathComponent:@"network_dump.txt"];
}

static void writeLog(NSString *msg) {
    NSString *path = dumpPath();
    NSString *line = [NSString stringWithFormat:@"%@\n---\n", msg];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) {
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        fh = [NSFileHandle fileHandleForWritingAtPath:path];
    }
    [fh seekToEndOfFile];
    [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
}

@interface NetworkLogger : NSURLProtocol <NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, strong) NSHTTPURLResponse *httpResponse;
@end

@implementation NetworkLogger

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if ([NSURLProtocol propertyForKey:@"LoggedRequest" inRequest:request]) return NO;
    NSString *scheme = request.URL.scheme.lowercaseString;
    return [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSMutableURLRequest *req = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:@"LoggedRequest" inRequest:req];

    NSMutableString *log = [NSMutableString string];
    [log appendFormat:@"[%@]\n", [NSDate date]];
    [log appendFormat:@"URL: %@\n", req.URL.absoluteString];
    [log appendFormat:@"Method: %@\n", req.HTTPMethod];
    [log appendString:@"Headers:\n"];
    [req.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(id k, id v, BOOL *s) {
        [log appendFormat:@"  %@: %@\n", k, v];
    }];
    if (req.HTTPBody) {
        NSString *body = [[NSString alloc] initWithData:req.HTTPBody encoding:NSUTF8StringEncoding];
        [log appendFormat:@"Body: %@\n", body ?: @"<binary>"];
    }
    writeLog(log);

    self.responseData = [NSMutableData data];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    [[self.session dataTaskWithRequest:req] resume];
}

- (void)stopLoading {
    [self.session invalidateAndCancel];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    self.httpResponse = (NSHTTPURLResponse *)response;
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
    [self.client URLProtocol:self didLoadData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        [self.client URLProtocol:self didFailWithError:error];
        writeLog([NSString stringWithFormat:@"ERROR: %@\n%@", task.originalRequest.URL, error.localizedDescription]);
    } else {
        NSMutableString *log = [NSMutableString string];
        [log appendFormat:@"RESPONSE: %@\n", task.originalRequest.URL.absoluteString];
        if (self.httpResponse) {
            [log appendFormat:@"Status: %ld\n", (long)self.httpResponse.statusCode];
            [log appendString:@"Headers:\n"];
            [self.httpResponse.allHeaderFields enumerateKeysAndObjectsUsingBlock:^(id k, id v, BOOL *s) {
                [log appendFormat:@"  %@: %@\n", k, v];
            }];
        }
        NSString *body = [[NSString alloc] initWithData:self.responseData encoding:NSUTF8StringEncoding];
        [log appendFormat:@"Body:\n%@\n", body ?: @"<binary>"];
        writeLog(log);
        [self.client URLProtocolDidFinishLoading:self];
    }
}

@end

%ctor {
    [NSURLProtocol registerClass:[NetworkLogger class]];
}
