//
//  InstrProfiling.h
//  CodeCoverageKit
//
//  Created by 李鑫 on 2020/6/24.
//  Copyright © 2020 Lision. All rights reserved.
//

#ifndef InstrProfiling_h
#define InstrProfiling_h

#if TARGET_IPHONE_SIMULATOR
// Not currently supported simulator
#else

#import <CommonCrypto/CommonHMAC.h>

#define CC_SHA256_DIGEST_LENGTH 32
typedef uint32_t CC_LONG;
FOUNDATION_EXPORT unsigned char *CC_SHA256(const void *data, CC_LONG len, unsigned char *md)
API_AVAILABLE(macos(10.4), ios(2.0));

FOUNDATION_EXPORT void __llvm_profile_initialize_file(void);
FOUNDATION_EXPORT void __llvm_profile_set_filename(char *);
FOUNDATION_EXPORT const char *__llvm_profile_get_filename(void);
FOUNDATION_EXPORT int __llvm_profile_write_file(void);
FOUNDATION_EXPORT int __llvm_profile_register_write_file_atexit(void);

#endif

#endif /* InstrProfiling_h */
