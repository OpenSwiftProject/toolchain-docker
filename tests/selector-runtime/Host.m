#include <assert.h>
#include <dlfcn.h>
#include <objc/runtime.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>

typedef SEL (*SelectorFunction)(void);

static SelectorFunction first;
static SelectorFunction second;
static SelectorFunction otherImage;
static SelectorFunction dynamicOnly;

static SelectorFunction lookup(void *image, const char *name) {
  SelectorFunction function = (SelectorFunction)dlsym(image, name);
  assert(function != NULL);
  return function;
}

static void *checkSelectors(void *unused) {
  (void)unused;
  for (unsigned i = 0; i != 1000; ++i) {
    // Within one ELF image, Swift records coalesce across object files.
    assert(first() == second());
    assert(strcmp(sel_getName(first()), "help:me:") == 0);
    assert(sel_isEqual(first(), @selector(help:me:)));
    assert(sel_isEqual(first(), sel_registerName("help:me:")));
    // Across DSOs, equality is semantic, not necessarily pointer identity.
    assert(sel_isEqual(first(), otherImage()));
    assert(strcmp(sel_getName(dynamicOnly()), "dynamicOnly:") == 0);
    assert(sel_isEqual(dynamicOnly(), sel_registerName("dynamicOnly:")));
  }
  return NULL;
}

int main(int argc, char **argv) {
  assert(argc == 3);
  // Each DSO contains only Swift SIL objects, no Objective-C implementation
  // object and no selector shim. Its own image initializer must register SELs.
  void *image = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
  if (!image) {
    fprintf(stderr, "%s\n", dlerror());
    return 1;
  }
  void *other = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
  if (!other) {
    fprintf(stderr, "%s\n", dlerror());
    return 1;
  }
  first = lookup(image, "selector_first");
  second = lookup(image, "selector_second");
  dynamicOnly = lookup(image, "selector_dynamic_only");
  otherImage = lookup(other, "selector_second");
  pthread_t threads[4];
  for (unsigned i = 0; i != 4; ++i)
    assert(pthread_create(&threads[i], NULL, checkSelectors, NULL) == 0);
  for (unsigned i = 0; i != 4; ++i)
    assert(pthread_join(threads[i], NULL) == 0);
  puts("GNUstep selector-only DSOs, coalescing, Clang equality, and concurrent lookup passed");
  // libobjc2 owns registered selector records for the process lifetime; this
  // test deliberately does not claim Objective-C image unloading support.
  return 0;
}
