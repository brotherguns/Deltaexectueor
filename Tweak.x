#import <Foundation/Foundation.h>

// Helper function to rip the request data and append it to our dump file
static void FoxDumpNetworkRequest(NSURLRequest *request) {
    if (!request || !request.URL) return;

    NSString *url = request.URL.absoluteString;
    NSString *method = request.HTTPMethod ?: @"GET";
    NSDictionary *headers = request.allHTTPHeaderFields;
    
    NSString *bodyString = @"[No Body or Unreadable]";
    if (request.HTTPBody) {
        // Attempt to parse body as UTF-8 string (JSON/Forms usually work here)
        NSString *parsedBody = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
        if (parsedBody) {
            bodyString = parsedBody;
        }
    }

    // Format the payload
    NSString *logEntry = [NSString stringWithFormat:@"\n========================================\n"
                                                     "TIME: %@\n"
                                                     "METHOD: %@\n"
                                                     "URL: %@\n"
                                                     "HEADERS: %@\n"
                                                     "BODY: %@\n"
                                                     "========================================\n", 
                          [NSDate date], method, url, headers, bodyString];

    // Find the Documents directory (Visible in Files App / iTunes Sharing)
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];
    NSString *logFilePath = [documentsDirectory stringByAppendingPathComponent:@"Fox_Network_Dump.txt"];

    // Append to file, create it if it doesn't exist
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:logFilePath]) {
        [logEntry writeToFile:logFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:[logEntry dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
    }
}

// Hooking the main NSURLSession methods responsible for outbound traffic
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    FoxDumpNetworkRequest(request);
    return %orig;
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(id)completionHandler {
    FoxDumpNetworkRequest(request);
    return %orig;
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url {
    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    FoxDumpNetworkRequest(req);
    return %orig;
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(id)completionHandler {
    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    FoxDumpNetworkRequest(req);
    return %orig;
}

%end // <-- This was the missing closing tag

// Hooking older NSURLConnection methods just in case they use legacy shit
%hook NSURLConnection

+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error {
    FoxDumpNetworkRequest(request);
    return %orig;
}

+ (void)sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue completionHandler:(id)handler {
    FoxDumpNetworkRequest(request);
    return %orig;
}

%end
