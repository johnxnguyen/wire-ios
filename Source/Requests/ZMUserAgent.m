// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.


#import "ZMUserAgent.h"
#import <mach-o/dyld.h>

@implementation ZMUserAgent

+ (void)setUserAgentOnRequest:(NSMutableURLRequest *)request;
{
    [request setValue:[self userAgentValue] forHTTPHeaderField:@"User-Agent"];
}


+ (NSString *)userAgentValue;
{
    static NSString *userAgentValue;
    if (userAgentValue == nil) {
        // This is covered by Section 5.5.3 of HTTP/1.1 Semantics and Content
        // <http://tools.ietf.org/html/rfc7231#section-5.5.3>
        //
        // Basically:
        //
        //     ProductName1/Version1 (Comments1) ProductName2/Version2 (Comments2) ...
        
        NSMutableString *agent = [NSMutableString string];
        
        // zmessaging:
        [agent appendFormat:@"zmessaging/%@ ", [[[NSBundle bundleForClass:NSClassFromString(@"ZMUserSession")] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
        [agent appendFormat:@"ztransport/%@ ", [[[NSBundle bundleForClass:self] infoDictionary] objectForKey:@"CFBundleVersion"]];
        [agent appendFormat:@"(iOS; %@)", [NSLocale currentLocale].localeIdentifier];
        
        // CFNetwork (which we use for all our networking)
        int32_t version = NSVersionOfRunTimeLibrary("CFNetwork");
        if (version != -1) {
            [agent appendString:@" CFNetwork/"];
            uint16_t const a = ((uint32_t) version) >> 16;
            uint8_t const b = (((uint32_t) version) >> 8) & 0xf;
            uint8_t const c = ((uint32_t) version) & 0xf;
            [agent appendFormat:@"%u.%u.%u", a, b, c];
        }
        userAgentValue = [agent copy];
    }
    return userAgentValue;
}


@end
