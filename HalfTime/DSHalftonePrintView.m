//
//  DSHalftonePrintView.m
//  HalfTime
//
//  Created by David Selassie on 11/11/11.
/*  Copyright (c) 2011 David Selassie. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 - Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 - Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "DSHalftonePrintView.h"

#import <Quartz/Quartz.h>

NSSize NSFitSizeInSize(NSSize size, NSSize maxFrame)
{
    CGFloat heightQuotient = size.height / maxFrame.height;
    CGFloat widthQuotient = size.width / maxFrame.width;

    NSSize result;
    if(heightQuotient >= widthQuotient)
        result = NSMakeSize(size.width / heightQuotient, maxFrame.height / heightQuotient);
    else
        result = NSMakeSize(size.width / widthQuotient, maxFrame.height / widthQuotient);
    
    return result;
}

NSRect NSMakeZeroRectFromSize(NSSize size)
{
    return NSMakeRect(0, 0, size.width, size.height);
}

NSRect NSCenterRectInRect(NSRect frame, CGFloat radius)
{
    return NSMakeRect(frame.origin.x + frame.size.width / 2.0 - radius / 2.0, frame.origin.y + frame.size.height / 2.0 - radius / 2.0, radius, radius);
}

@implementation DSHalftonePrintView

- (NSInteger)pagesHigh
{
    return ceil(self.bounds.size.height / self.paperSize.height);
}

- (NSInteger)pagesWide
{
    return ceil(self.bounds.size.width / self.paperSize.width);
}

@synthesize pixelatedImageRep;
@synthesize paperSize;
@synthesize dotSize;
@synthesize zoom;
@synthesize labelAttributes;

- (void)setPageBounds:(NSRect)pageBounds
{
    self.paperSize = pageBounds.size;
}

- (NSRect)pageBounds
{
    return NSMakeZeroRectFromSize(self.paperSize);
}

- (BOOL)isFlipped
{
    return YES;
}

- (void)setImage:(NSImage *)newImage
{
    [super setImage:newImage];
    
    if (self.image) {
        self.window.contentAspectRatio = self.image.size;
        
        NSRect newFrame = self.window.frame;
        newFrame.size = self.image.size;
        [self.window setFrame:newFrame display:TRUE animate:TRUE];
    }
}

- (id)initWithFrame:(NSRect)frameRect
{
    if (self = [super initWithFrame:frameRect]) {
        self.labelAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont fontWithName:@"Helvetica Neue" size:36], NSFontAttributeName, [NSColor colorWithDeviceRed:70.0/255.0 green:130.0/255.0 blue:180.0/255.0 alpha:1], NSForegroundColorAttributeName, nil];
        
        self.dotSize = 20.0;
        self.zoom = 1.0;
        
        [self addObserver:self forKeyPath:@"dotSize" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:nil];
        [self addObserver:self forKeyPath:@"zoom" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:nil];
        [self addObserver:self forKeyPath:@"paperSize" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:nil];
        
        //[NSBezierPath setDefaultFlatness:100.0];
    }
    
    return self;
}

- (BOOL)knowsPageRange:(NSRangePointer)range
{
    range->location = 1;
    range->length = self.pagesHigh * self.pagesWide;
    
    return YES;
}

- (NSRect)rectForPage:(NSInteger)page
{
    // Input page count starts at 1, not 0 and the math below works better if the first page is 0.
    page--;
    
    // Assume that page is "across major" or across varies most quickly.
    NSInteger pageAcross = page % self.pagesWide;
    NSInteger pageDown = page / self.pagesWide;
    
    return NSMakeRect(pageAcross * paperSize.width, pageDown * paperSize.height, paperSize.width, paperSize.height);
}

- (void)setFrameSize:(NSSize)newSize
{
    // Has to be called first, otherwise strange lag times.
    [super setFrameSize:newSize];
    
    if (self.image) {
        // This contains a scaled down (or up) version of the image where each dot in the halftone print is one pixel in this image.
        NSImage *pixelatedImage = [[NSImage alloc] initWithSize:NSMakeSize(self.bounds.size.width / dotSize, self.bounds.size.height / dotSize)];
        
        [pixelatedImage lockFocus];
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        [self.image drawInRect:NSMakeZeroRectFromSize(pixelatedImage.size) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        [pixelatedImage unlockFocus];
        
        self.pixelatedImageRep = [[NSBitmapImageRep alloc] initWithData:[pixelatedImage TIFFRepresentation]];
    }
    else {
        self.pixelatedImageRep = nil;
    }
}

- (void)viewDidEndLiveResize
{
    [super viewDidEndLiveResize];
    
    // Update view so high quality dots get drawn.
    [self setNeedsDisplay];
}

- (void)drawRect:(NSRect)dirtyRect
{
    if ([NSGraphicsContext currentContextDrawingToScreen]) {
        //[self scaleUnitSquareToSize:NSMakeSize(0.5, 0.5)];
    }
    else {
        //[self scaleUnitSquareToSize:NSMakeSize(1, 1)];
    }
    
    if (self.pixelatedImageRep) {
        // Raw image scaling:
        //[self.image drawInRect:self.bounds fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        
        // CI halftone image drawing:
        /*CIImage *input = [[CIImage alloc] initWithData:[self.image TIFFRepresentation]];
        CIImage *output;
        
        CIFilter *halftoneFilter = [CIFilter filterWithName:@"CIDotScreen"];
        [halftoneFilter setValue:input forKey:@"inputImage"];
        [halftoneFilter setValue:[CIVector vectorWithX:0 Y:0] forKey:@"inputCenter"];
        [halftoneFilter setValue:[NSNumber numberWithFloat:0] forKey:@"inputAngle"];
        [halftoneFilter setValue:[NSNumber numberWithFloat:self.dotSize] forKey:@"inputWidth"];
        [halftoneFilter setValue:[NSNumber numberWithFloat:1] forKey:@"inputSharpness"];
        output = [halftoneFilter valueForKey:@"outputImage"];
        
        NSImage *outNS = [[NSImage alloc] initWithSize:self.bounds.size];
        [outNS addRepresentation:[NSCIImageRep imageRepWithCIImage:output]];
        
        [outNS drawInRect:self.bounds fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];*/
        
        [[NSColor blackColor] set];
        for (CGFloat dotX = floor(dirtyRect.origin.x / dotSize) * dotSize; dotX <= dirtyRect.origin.x + dirtyRect.size.width; dotX += dotSize) {
            for (CGFloat dotY = floor(dirtyRect.origin.y / dotSize) * dotSize; dotY <= dirtyRect.origin.y + dirtyRect.size.height; dotY += dotSize) {
                NSRect fullDotRect = NSMakeRect(dotX, dotY, dotSize, dotSize);
                
                CGFloat black = 1.0 - [pixelatedImageRep colorAtX:dotX / dotSize y:dotY / dotSize].brightnessComponent;
                CGFloat radius = black * dotSize;
                
                if (!self.inLiveResize) {
                    radius *= sqrt(2.0);
                }
                
                NSRect dotRect = NSCenterRectInRect(fullDotRect, radius);
                
                if (NSIntersectsRect(dirtyRect, dotRect)) {
                    if ([NSGraphicsContext currentContextDrawingToScreen] && self.inLiveResize) {
                        NSRectFill(dotRect);
                    }
                    else {
                        [[NSBezierPath bezierPathWithOvalInRect:dotRect] fill];
                    }
                }
            }
        }
    }
    
    if ([NSGraphicsContext currentContextDrawingToScreen]) {
        // Draw page outlines.
        [[NSColor grayColor] set];
        [NSBezierPath setDefaultLineWidth:1.0 / self.zoom];
        
        for (NSInteger xPage = 0; xPage < self.pagesWide; xPage++) {
            for (NSInteger yPage = 0; yPage < self.pagesHigh; yPage++) {
                NSRect pageRect = NSMakeRect(xPage * paperSize.width, yPage * paperSize.height, paperSize.width, paperSize.height);

                if (NSIntersectsRect(dirtyRect, pageRect)) {
                    //NSFrameRect(pageRect);
                    [NSBezierPath strokeRect:pageRect];
                }
            }
        }
        
        NSInteger actualPagesWide = self.pagesWide, actualPagesHigh = self.pagesHigh;
        
        // Reset scale just for drawing text.
        self.bounds = self.frame;
        [self scaleUnitSquareToSize:NSMakeSize(1.0, 1.0)];
        
        // Draw page count in corner.
        [[NSString stringWithFormat:@"%i x %i sheets", actualPagesWide, actualPagesHigh] drawAtPoint:NSMakePoint(20, 10) withAttributes:labelAttributes];
        
        if (!self.pixelatedImageRep) {
            [[NSString stringWithFormat:@"Drop an image here.", actualPagesWide, actualPagesHigh] drawAtPoint:NSMakePoint(20, 60) withAttributes:labelAttributes];
            [[NSString stringWithFormat:@"Resize the window.", actualPagesWide, actualPagesHigh] drawAtPoint:NSMakePoint(20, 110) withAttributes:labelAttributes];
        }
        
        // Set the scale back.
        self.bounds = self.frame;
        [self scaleUnitSquareToSize:NSMakeSize(self.zoom, self.zoom)];
        
    } else {

    }
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    return YES;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    NSPasteboard *board = [sender draggingPasteboard];
    NSArray *fileArray = [board propertyListForType:NSFilenamesPboardType];
    
    if (!fileArray) {
        return NSDragOperationNone;
    }
    
    return NSDragOperationCopy;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    NSPasteboard *board = [sender draggingPasteboard];
    NSArray *fileArray = [board propertyListForType:NSFilenamesPboardType];
    
    if (!fileArray) {
        return NO;
    }
    
    NSString *path = [fileArray objectAtIndex:0];
    
    self.image = [[NSImage alloc] initWithContentsOfFile:path];
    
    return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
    
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == self) {
        if ([keyPath isEqualToString:@"dotSize"]) {
            // Forces recalculation of the pixelated image.
            [self setFrameSize:self.frame.size];
        }
        if ([keyPath isEqualToString:@"zoom"]) {
            self.bounds = self.frame;
            [self scaleUnitSquareToSize:NSMakeSize(self.zoom, self.zoom)];
            [self setFrameSize:self.frame.size];
        }
        
        [self setNeedsDisplay];
    }
}

@end
