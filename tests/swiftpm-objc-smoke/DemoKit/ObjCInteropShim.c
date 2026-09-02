// Known issue: remove when OpenSwiftProject/swift#2 provides these runtime
// metadata entry points for GNUstep Objective-C interop.
#include <objc/runtime.h>

Class objc_opt_self(Class cls) {
  return cls;
}

const void *swift_getObjCClassMetadata(Class cls) {
  return cls;
}

Class swift_getObjCClassFromMetadata(const void *metadata) {
  return (Class)metadata;
}

Class swift_getObjCClassFromMetadataConditional(const void *metadata) {
  return (Class)metadata;
}
