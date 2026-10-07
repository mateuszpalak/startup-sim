// Simulator only: the official Godot iOS template has no arm64 simulator
// slice, so tools/build-ios.sh links the device library retagged for the
// simulator. Two Metal error domains it references are missing from the
// simulator's Metal.framework; these stand in for them.
#import <Foundation/Foundation.h>
NSString *const MTLIOErrorDomain = @"MTLIOErrorDomain";
NSString *const MTLTensorDomain = @"MTLTensorDomain";
