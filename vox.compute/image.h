//  Copyright (c) 2022 Feng Yang
//
//  I am making my contributions/submissions to this project solely in my
//  personal capacity and am not conveying any rights to any intellectual
//  property of any third parties.

#import <Foundation/Foundation.h>

@interface AAPLImage : NSObject

// Initialize this image by loading a *very* simple TGA file.
// The sample can't load compressed, paletted, or color mapped images.
- (nullable instancetype)initWithTGAFileAtLocation:(nonnull NSURL *)location;

// Width of image in pixels.
@property(nonatomic, readonly) NSUInteger width;

// Height of image in pixels.
@property(nonatomic, readonly) NSUInteger height;

// Image data is in 32-bits-per-pixel (bpp) BGRA form (which is equivalent to MTLPixelFormatBGRA8Unorm).
@property(nonatomic, readonly, nonnull) NSData *data;

@end
