// PluginInstaller.m
//
// Copyright (c) 2013 mneorr.com
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


#import "PluginInstaller.h"
#import "Plugin.h"
#import "Shell.h"
#import "Git.h"

static NSString *const LOCAL_PLUGINS_RELATIVE_PATH = @"Library/Application Support/Developer/Shared/Xcode/Plug-ins";

@implementation PluginInstaller

#pragma mark - Public

- (void)installPackage:(Plugin *)plugin progress:(void (^)(CGFloat))progress
            completion:(void (^)(void))completion failure:(void (^)(NSError *))failure {

    [self clonePlugin:plugin
           completion:^{ [self buildPlugin:plugin completion:completion failure:failure]; }
              failure:failure];
}

- (void)removePackage:(Plugin *)package
           completion:(void (^)(void))completion failure:(void (^)(NSError *))failure {

    [[NSFileManager sharedManager] removeItemAtPath:[self pathForInstalledPackage:package]
                                         completion:completion
                                            failure:failure];
}

- (BOOL)isPackageInstalled:(Plugin *)package {
    BOOL isDirectory;
    return [[NSFileManager sharedManager] fileExistsAtPath:[self pathForInstalledPackage:package] isDirectory:&isDirectory];
}


#pragma mark - Private

- (NSString *)pathForInstalledPackage:(Package *)package {
    return [[[NSHomeDirectory() stringByAppendingPathComponent:LOCAL_PLUGINS_RELATIVE_PATH]
                                stringByAppendingPathComponent:package.name]
                                       stringByAppendingString:@".xcplugin"];
}

- (void)clonePlugin:(Plugin *)plugin completion:(void(^)(void))completion failure:(void (^)(NSError *))failure {

    if ([self pluginIsAlreadyCloned:plugin])
        [Git updateLocalProject:[self pathForClonedPlugin:plugin]];
    else
        [Git clone:plugin.remotePath to:[self pathForClonedPlugin:plugin]];

    completion();
}

- (BOOL)pluginIsAlreadyCloned:(Plugin *)plugin {
    return [[NSFileManager sharedManager] fileExistsAtPath:[self pathForClonedPlugin:plugin]];
}

- (NSString *)pathForClonedPlugin:(Plugin *)plugin {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:plugin.name];
}

- (void)buildPlugin:(Plugin *)plugin completion:(void(^)(void))completion failure:(void (^)(NSError *))failure {
    Shell *shell = [Shell new];

    [shell executeCommand:@"/usr/bin/xcodebuild"
            withArguments:@[@"-project", [self findXcodeprojPathForPlugin:plugin]]
               completion:^(NSString *output) {

        NSLog(@"Xcodebuild output: %@", output);
        completion();
        [shell release];
    }];
}

- (NSString *)findXcodeprojPathForPlugin:(Plugin *)plugin {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    @try {
        NSString *path = [self pathForClonedPlugin:plugin];
        NSDirectoryEnumerator *enumerator = [[NSFileManager sharedManager] enumeratorAtPath:path];
        
        NSString *directoryEntry;
        while (directoryEntry = [enumerator nextObject]) {
            if ([directoryEntry hasSuffix:@".xcodeproj"])
                return [path stringByAppendingPathComponent:directoryEntry];
        }
    }
    @catch (NSException *exception) { NSLog(@"Exception with finding xcodeproj path! %@", exception); }
    @finally { NSLog(@"draining..."); [pool drain]; }

    return @"";
}

@end
