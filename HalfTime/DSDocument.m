//
//  DSDocument.m
//  HalfTime
//
//  Created by David Selassie on 11/14/11.
/*  Copyright (c) 2011 David Selassie. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 - Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 - Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "DSDocument.h"

@implementation DSDocument

@synthesize image;
@synthesize dotSize;
@synthesize zoom;
@synthesize imageFrame;
@synthesize halftoneView;
@synthesize halftoneWindow;

- (id)init
{
    if (self = [super init]) {
        self.dotSize = 20.0;
        self.zoom = 1.0;
        self.image = nil;
        self.imageFrame = NSMakeRect(100, 500, 500, 500);
    }
    
    return self;
}

- (NSString *)windowNibName
{
    return @"DSDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
    
    [self addObserver:self forKeyPath:@"imageFrame" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:nil];
    [self addObserver:self forKeyPath:@"dotSize" options:NSKeyValueObservingOptionNew context:nil];
    [self addObserver:self forKeyPath:@"zoom" options:NSKeyValueObservingOptionNew context:nil];

    [self.halftoneView bind:@"dotSize" toObject:self withKeyPath:@"dotSize" options:nil];
    [self.halftoneView bind:@"zoom" toObject:self withKeyPath:@"zoom" options:nil];
    [self.halftoneView bind:@"pageBounds" toObject:self withKeyPath:@"printInfo.imageablePageBounds" options:nil];
    //[self.halftoneView bind:@"paperSize" toObject:self withKeyPath:@"printInfo.paperSize" options:nil];
    
    [self.halftoneView bind:@"image" toObject:self withKeyPath:@"image" options:nil];
    [self bind:@"image" toObject:self.halftoneView withKeyPath:@"image" options:nil];
    
    [self.halftoneWindow bind:@"frame" toObject:self withKeyPath:@"imageFrame" options:nil];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    if ([typeName isEqualToString:@"HalfTimeDocumentType"]) {
        return [NSKeyedArchiver archivedDataWithRootObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[self.image TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1], @"imageData", [NSNumber numberWithFloat:self.dotSize], @"dotSize", [NSNumber numberWithFloat:self.zoom], @"zoom", [NSValue valueWithRect:self.printInfo.imageablePageBounds], @"paperPrintableRect", self.printInfo.paperName, @"paperName", [NSValue valueWithRect:self.windowForSheet.frame], @"windowFrame", nil]];
    }
    
    return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    if ([typeName isEqualToString:@"HalfTimeDocumentType"]) {
        NSMutableDictionary *dict = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        
        self.dotSize = [[dict objectForKey:@"dotSize"] floatValue];
        self.zoom = [[dict objectForKey:@"zoom"] floatValue];
        self.printInfo.paperName = [dict objectForKey:@"paperName"];
        self.image = [[NSImage alloc] initWithData:[dict objectForKey:@"imageData"]];
        self.imageFrame = [[dict objectForKey:@"windowFrame"] rectValue];
        
        return YES;
    }
    
    return NO;
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

/*- (BOOL)shouldChangePrintInfo:(NSPrintInfo *)newPrintInfo
{
    [self willChangeValueForKey:@"printInfo.paperSize"];
    BOOL val = [super shouldChangePrintInfo:newPrintInfo];
    [self didChangeValueForKey:@"printInfo.paperSize"];
    
    return val;
}*/

- (void)printDocument:(id)sender
{
    [halftoneView print:sender];
}

- (IBAction)decreaseDotSize:(id)sender
{
    self.dotSize -= 5.0;
}

- (IBAction)increaseDotSize:(id)sender
{
    self.dotSize += 5.0;
}

- (IBAction)zoomOut:(id)sender
{
    self.zoom /= 2.0;
}

- (IBAction)zoomIn:(id)sender
{
    self.zoom *= 2.0;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == self) {
        if ([keyPath isEqualToString:@"dotSize"]) {
            if (dotSize < 5.0) {
                self.dotSize = 5.0;
            }
            if (dotSize > 70.0) {
                self.dotSize = 70.0;
            }
        }
        else if ([keyPath isEqualToString:@"zoom"]) {
            if (zoom < 0.05) {
                self.zoom = 0.05;
            }
            if (zoom > 32.0) {
                self.zoom = 32.0;
            }
        }
    }
}

@end
