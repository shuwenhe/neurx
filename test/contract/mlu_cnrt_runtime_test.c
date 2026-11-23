#include <cnrt.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

static bool check(const char *operation, cnrtRet_t status) {
    if (status == cnrtSuccess) {
        printf("%s -> %u\n", operation, (unsigned int)status);
        return true;
    }
    const char *message = cnrtGetErrorStr(status);
    fprintf(stderr, "%s -> %u (%s)\n", operation, (unsigned int)status,
            message ? message : "unknown CNRT error");
    return false;
}

#define CHECK(call) check(#call, (call))

static bool test_device(int ordinal) {
    cnrtDeviceProp_t properties;
    int selected = -1;
    printf("device %d\n", ordinal);
    if (!CHECK(cnrtSetDevice(ordinal)) ||
        !CHECK(cnrtGetDevice(&selected)) ||
        !CHECK(cnrtGetDeviceProperties(&properties, ordinal)))
        return false;
    if (selected != ordinal) {
        fprintf(stderr, "selected device %d, expected %d\n", selected, ordinal);
        return false;
    }
    printf("name=%.256s memory_mb=%d\n", properties.name, properties.totalMem);

    cnrtQueue_t queue;
    if (!CHECK(cnrtQueueCreate(&queue)))
        return false;

    unsigned char sent[4096], received[sizeof(sent)];
    for (size_t i = 0; i < sizeof(sent); ++i)
        sent[i] = (unsigned char)(i * 31u);
    memset(received, 0, sizeof(received));

    void *device;
    bool passed = CHECK(cnrtMalloc(&device, sizeof(sent)));
    if (passed) {
        passed = CHECK(cnrtMemcpy(device, sent, sizeof(sent), cnrtMemcpyHostToDev)) &&
                 CHECK(cnrtMemcpy(received, device, sizeof(received), cnrtMemcpyDevToHost));
        if (passed && memcmp(sent, received, sizeof(sent)) != 0) {
            fprintf(stderr, "device %d round-trip data mismatch\n", ordinal);
            passed = false;
        }
        if (!CHECK(cnrtFree(device)))
            passed = false;
    }
    if (!CHECK(cnrtQueueSync(queue)))
        passed = false;
    if (!CHECK(cnrtQueueDestroy(queue)))
        passed = false;
    return passed;
}

int main(void) {
    int major, minor, patch;
    unsigned int count = 0;
    if (!CHECK(cnrtGetLibVersion(&major, &minor, &patch)))
        return 1;
    printf("CNRT %d.%d.%d\n", major, minor, patch);
    if (!CHECK(cnrtGetDeviceCount(&count)))
        return 1;
    printf("device_count=%u\n", count);
    if (count == 0 || count > INT_MAX) {
        fprintf(stderr, "unusable CNRT device count: %u\n", count);
        return 1;
    }

    bool passed = true;
    for (unsigned int i = 0; i < count; ++i) {
        if (!test_device((int)i))
            passed = false;
    }
    if (passed)
        puts("PASS: CNRT runtime smoke test");
    return passed ? 0 : 1;
}
