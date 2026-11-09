#ifndef HENGEVM_METALLIB_H
#define HENGEVM_METALLIB_H

#include <stddef.h>
#include <stdint.h>

/* iPadOS and iOS 15's Metal refuse the libraries macOS 15 and later send ("This library format is not supported
   on this platform"): they say macOS, library file version 2.8 and AIR 2.7, where iOS 15 reads iOS, 2.5 and
   AIR 2.4. This relabels a library in place as one built for iOS 15. Stage 1: the header and each function's
   version tag. Stage 2 also: each function's bitcode target triple (same length, "air64_v24-apple-ios15.0.0"
   padded with zeros) and so its hash. The code itself is unchanged: an iOS 15 that compiles it accepts AIR it
   can read. Returns how many fields changed, or -1 if it isn't a library this understands. */
int hv_metallib_relabel(uint8_t *buf, size_t len, int stage);

#endif
