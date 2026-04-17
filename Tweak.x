#import <Foundation/Foundation.h>

static NSString *logPath() {
    NSArray *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *dir = docs.firstObject ?: @"/tmp";
    return [dir stringByAppendingPathComponent:@"network_dump.txt"];
}

static void appendLog(NSString *entry) {
    NSString *path = logPath();
    NSString *line = [NSString stringWithFormat:@"%@\n---\n", entry];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) {
        [@"" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        fh = [NSFileHandle fileHandleForWritingAtPath:path];
    }
    [fh seekToEndOfFile];
    [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
}

// Hook NSURLSession dataTaskWithRequest
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    return %orig(request, ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSMutableString *log = [NSMutableString string];
        [log appendFormat:@"[%@] REQUEST\n", [NSDate date]];
        [log appendFormat:@"URL: %@\n", request.URL.absoluteString];
        [log appendFormat:@"Method: %@\n", request.HTTPMethod];

        // Request headers
        [log appendString:@"Request Headers:\n"];
        [request.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(id k, id v, BOOL *s) {
            [log appendFormat:@"  %@: %@\n", k, v];
        }];

        // Request body
        if (request.HTTPBody) {
            NSString *body = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
            [log appendFormat:@"Request Body:\n%@\n", body ?: @"<binary>"];
        }

        // Response
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            [log appendFormat:@"Status: %ld\n", (long)http.statusCode];
            [log appendString:@"Response Headers:\n"];
            [http.allHeaderFields enumerateKeysAndObjectsUsingBlock:^(id k, id v, BOOL *s) {
                [log appendFormat:@"  %@: %@\n", k, v];
            }];
        }

        // Response body
        if (data) {
            NSString *responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            [log appendFormat:@"Response Body:\n%@\n", responseBody ?: @"<binary>"];
        }

        if (error) {
            [log appendFormat:@"Error: %@\n", error.localizedDescription];
        }

        appendLog(log);

        if (completionHandler) completionHandler(data, response, error);
    });
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    return [self dataTaskWithRequest:req completionHandler:completionHandler];
}

%end
