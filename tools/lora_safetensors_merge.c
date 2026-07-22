#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#ifndef _FILE_OFFSET_BITS
#define _FILE_OFFSET_BITS 64
#endif

typedef struct {
    char name[512];
    char dtype[16];
    long shape[8];
    int rank;
    uint64_t begin;
    uint64_t end;
} tensor_info;

typedef struct {
    char *header;
    uint64_t header_len;
    uint64_t data_base;
} st_index;

static uint64_t read_u64_le(const unsigned char *p) {
    uint64_t v = 0;
    for (int i = 7; i >= 0; i--) v = (v << 8) | p[i];
    return v;
}

static uint16_t read_u16_le(const unsigned char *p) {
    return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}

static void write_u16_le(unsigned char *p, uint16_t v) {
    p[0] = (unsigned char)(v & 255);
    p[1] = (unsigned char)(v >> 8);
}

static float u32_to_f32(uint32_t bits) {
    float out;
    memcpy(&out, &bits, sizeof(out));
    return out;
}

static uint32_t f32_to_u32(float value) {
    uint32_t out;
    memcpy(&out, &value, sizeof(out));
    return out;
}

static float bf16_to_f32(uint16_t v) {
    return u32_to_f32((uint32_t)v << 16);
}

static uint16_t f32_to_bf16(float value) {
    uint32_t bits = f32_to_u32(value);
    uint32_t lsb = (bits >> 16) & 1;
    bits += 0x7fff + lsb;
    return (uint16_t)(bits >> 16);
}

static float f16_to_f32(uint16_t h) {
    uint32_t sign = (uint32_t)(h & 0x8000) << 16;
    uint32_t exp = (h >> 10) & 0x1f;
    uint32_t mant = h & 0x03ff;
    if (exp == 0) {
        if (mant == 0) return u32_to_f32(sign);
        while ((mant & 0x0400) == 0) {
            mant <<= 1;
            exp--;
        }
        exp++;
        mant &= 0x03ff;
    } else if (exp == 31) {
        return u32_to_f32(sign | 0x7f800000u | (mant << 13));
    }
    exp = exp + (127 - 15);
    return u32_to_f32(sign | (exp << 23) | (mant << 13));
}

static uint16_t f32_to_f16(float value) {
    uint32_t x = f32_to_u32(value);
    uint32_t sign = (x >> 16) & 0x8000;
    int exp = (int)((x >> 23) & 0xff) - 127 + 15;
    uint32_t mant = x & 0x7fffff;
    if (exp <= 0) return (uint16_t)sign;
    if (exp >= 31) return (uint16_t)(sign | 0x7c00);
    return (uint16_t)(sign | ((uint32_t)exp << 10) | ((mant + 0x1000) >> 13));
}

static int dtype_size(const char *dtype) {
    if (strcmp(dtype, "F32") == 0) return 4;
    if (strcmp(dtype, "BF16") == 0) return 2;
    if (strcmp(dtype, "F16") == 0) return 2;
    return 0;
}

static int mkdir_p(const char *path) {
    char tmp[1024];
    size_t len = strlen(path);
    if (len >= sizeof(tmp)) return -1;
    strcpy(tmp, path);
    for (char *p = tmp + 1; *p; p++) {
        if (*p == '/') {
            *p = 0;
            if (mkdir(tmp, 0755) != 0 && errno != EEXIST) return -1;
            *p = '/';
        }
    }
    if (mkdir(tmp, 0755) != 0 && errno != EEXIST) return -1;
    return 0;
}

static int copy_file(const char *src, const char *dst) {
    FILE *in = fopen(src, "rb");
    FILE *out = NULL;
    unsigned char buf[1 << 20];
    size_t n;
    if (!in) return -1;
    out = fopen(dst, "wb");
    if (!out) {
        fclose(in);
        return -1;
    }
    while ((n = fread(buf, 1, sizeof(buf), in)) > 0) {
        if (fwrite(buf, 1, n, out) != n) {
            fclose(in);
            fclose(out);
            return -1;
        }
    }
    if (ferror(in) || fclose(out) != 0) {
        fclose(in);
        return -1;
    }
    fclose(in);
    return 0;
}

static void path_join(char *out, size_t cap, const char *a, const char *b) {
    snprintf(out, cap, "%s/%s", a, b);
}

static int copy_model_dir(const char *src_dir, const char *dst_dir) {
    DIR *dir = opendir(src_dir);
    struct dirent *ent;
    if (!dir) return -1;
    if (mkdir_p(dst_dir) != 0) {
        closedir(dir);
        return -1;
    }
    while ((ent = readdir(dir)) != NULL) {
        char src[1024], dst[1024];
        struct stat st;
        if (strcmp(ent->d_name, ".") == 0 || strcmp(ent->d_name, "..") == 0) continue;
        path_join(src, sizeof(src), src_dir, ent->d_name);
        path_join(dst, sizeof(dst), dst_dir, ent->d_name);
        if (stat(src, &st) != 0) continue;
        if (S_ISREG(st.st_mode) && copy_file(src, dst) != 0) {
            closedir(dir);
            return -1;
        }
    }
    closedir(dir);
    return 0;
}

static int load_st_index(const char *path, st_index *idx) {
    FILE *fp = fopen(path, "rb");
    unsigned char len_buf[8];
    if (!fp) return -1;
    if (fread(len_buf, 1, 8, fp) != 8) {
        fclose(fp);
        return -1;
    }
    idx->header_len = read_u64_le(len_buf);
    idx->data_base = 8 + idx->header_len;
    idx->header = (char *)malloc((size_t)idx->header_len + 1);
    if (!idx->header) {
        fclose(fp);
        return -1;
    }
    if (fread(idx->header, 1, (size_t)idx->header_len, fp) != (size_t)idx->header_len) {
        free(idx->header);
        fclose(fp);
        return -1;
    }
    idx->header[idx->header_len] = 0;
    fclose(fp);
    return 0;
}

static char *find_quoted_name(const char *header, const char *name) {
    size_t n = strlen(name);
    const char *p = header;
    while ((p = strstr(p, name)) != NULL) {
        if (p > header && p[-1] == '"' && p[n] == '"') return (char *)p - 1;
        p += n;
    }
    return NULL;
}

static int object_span(char *name_quote, char **obj_begin, char **obj_end) {
    char *p = strchr(name_quote, ':');
    int depth = 0;
    int in_str = 0;
    int esc = 0;
    if (!p) return -1;
    while (*p && *p != '{') p++;
    if (*p != '{') return -1;
    *obj_begin = p;
    for (; *p; p++) {
        char c = *p;
        if (in_str) {
            if (esc) esc = 0;
            else if (c == '\\') esc = 1;
            else if (c == '"') in_str = 0;
        } else {
            if (c == '"') in_str = 1;
            else if (c == '{') depth++;
            else if (c == '}') {
                depth--;
                if (depth == 0) {
                    *obj_end = p + 1;
                    return 0;
                }
            }
        }
    }
    return -1;
}

static int extract_dtype(char *begin, char *end, char out[16]) {
    char *p = strstr(begin, "\"dtype\"");
    if (!p || p >= end) return -1;
    p = strchr(p, ':');
    if (!p || p >= end) return -1;
    while (p < end && *p != '"') p++;
    if (p >= end) return -1;
    p++;
    char *q = strchr(p, '"');
    if (!q || q >= end || q - p >= 15) return -1;
    memcpy(out, p, (size_t)(q - p));
    out[q - p] = 0;
    return 0;
}

static int parse_int_list(char *p, char *end, long *out, int maxn, int *count) {
    int n = 0;
    while (p < end && *p != '[') p++;
    if (p >= end) return -1;
    p++;
    while (p < end && *p != ']') {
        while (p < end && !isdigit((unsigned char)*p) && *p != '-') p++;
        if (p >= end || *p == ']') break;
        if (n >= maxn) return -1;
        out[n++] = strtol(p, &p, 10);
    }
    *count = n;
    return 0;
}

static int extract_shape(char *begin, char *end, long *shape, int *rank) {
    char *p = strstr(begin, "\"shape\"");
    if (!p || p >= end) return -1;
    return parse_int_list(p, end, shape, 8, rank);
}

static int extract_offsets(char *begin, char *end, uint64_t *a, uint64_t *b) {
    long vals[2];
    int n = 0;
    char *p = strstr(begin, "\"data_offsets\"");
    if (!p || p >= end) return -1;
    if (parse_int_list(p, end, vals, 2, &n) != 0 || n != 2) return -1;
    *a = (uint64_t)vals[0];
    *b = (uint64_t)vals[1];
    return 0;
}

static int st_find_tensor(st_index *idx, const char *name, tensor_info *out) {
    char *q = find_quoted_name(idx->header, name);
    char *begin = NULL;
    char *end = NULL;
    if (!q || object_span(q, &begin, &end) != 0) return -1;
    memset(out, 0, sizeof(*out));
    snprintf(out->name, sizeof(out->name), "%s", name);
    if (extract_dtype(begin, end, out->dtype) != 0) return -1;
    if (extract_shape(begin, end, out->shape, &out->rank) != 0) return -1;
    if (extract_offsets(begin, end, &out->begin, &out->end) != 0) return -1;
    return 0;
}

static long numel(const tensor_info *t) {
    long n = 1;
    for (int i = 0; i < t->rank; i++) n *= t->shape[i];
    return n;
}

static float *read_tensor_as_f32(const char *path, const st_index *idx, const tensor_info *t) {
    int ds = dtype_size(t->dtype);
    long n = numel(t);
    uint64_t bytes = t->end - t->begin;
    unsigned char *raw = NULL;
    float *out = NULL;
    FILE *fp = NULL;
    if (ds == 0 || bytes != (uint64_t)n * (uint64_t)ds) return NULL;
    raw = (unsigned char *)malloc((size_t)bytes);
    out = (float *)malloc((size_t)n * sizeof(float));
    if (!raw || !out) goto fail;
    fp = fopen(path, "rb");
    if (!fp) goto fail;
    if (fseek(fp, (long)(idx->data_base + t->begin), SEEK_SET) != 0) goto fail;
    if (fread(raw, 1, (size_t)bytes, fp) != (size_t)bytes) goto fail;
    fclose(fp);
    fp = NULL;
    for (long i = 0; i < n; i++) {
        if (strcmp(t->dtype, "F32") == 0) {
            uint32_t bits = (uint32_t)raw[i * 4] | ((uint32_t)raw[i * 4 + 1] << 8) |
                            ((uint32_t)raw[i * 4 + 2] << 16) | ((uint32_t)raw[i * 4 + 3] << 24);
            out[i] = u32_to_f32(bits);
        } else if (strcmp(t->dtype, "BF16") == 0) {
            out[i] = bf16_to_f32(read_u16_le(raw + i * 2));
        } else if (strcmp(t->dtype, "F16") == 0) {
            out[i] = f16_to_f32(read_u16_le(raw + i * 2));
        }
    }
    free(raw);
    return out;
fail:
    if (fp) fclose(fp);
    free(raw);
    free(out);
    return NULL;
}

static int write_tensor_from_f32(FILE *fp, const st_index *idx, const tensor_info *t, const float *data) {
    int ds = dtype_size(t->dtype);
    long n = numel(t);
    unsigned char *raw = (unsigned char *)malloc((size_t)n * (size_t)ds);
    if (!raw) return -1;
    for (long i = 0; i < n; i++) {
        if (strcmp(t->dtype, "F32") == 0) {
            uint32_t bits = f32_to_u32(data[i]);
            raw[i * 4] = (unsigned char)(bits & 255);
            raw[i * 4 + 1] = (unsigned char)((bits >> 8) & 255);
            raw[i * 4 + 2] = (unsigned char)((bits >> 16) & 255);
            raw[i * 4 + 3] = (unsigned char)((bits >> 24) & 255);
        } else if (strcmp(t->dtype, "BF16") == 0) {
            write_u16_le(raw + i * 2, f32_to_bf16(data[i]));
        } else if (strcmp(t->dtype, "F16") == 0) {
            write_u16_le(raw + i * 2, f32_to_f16(data[i]));
        } else {
            free(raw);
            return -1;
        }
    }
    if (fseek(fp, (long)(idx->data_base + t->begin), SEEK_SET) != 0) {
        free(raw);
        return -1;
    }
    if (fwrite(raw, 1, (size_t)n * (size_t)ds, fp) != (size_t)n * (size_t)ds) {
        free(raw);
        return -1;
    }
    free(raw);
    return 0;
}

static void peft_to_base_name(const char *a_name, char *base, size_t cap) {
    const char *p = a_name;
    const char *prefix = "base_model.model.";
    size_t prefix_len = strlen(prefix);
    if (strncmp(p, prefix, prefix_len) == 0) p += prefix_len;
    snprintf(base, cap, "%s", p);
    char *suffix = strstr(base, ".lora_A.weight");
    if (suffix) strcpy(suffix, ".weight");
    if (strncmp(base, "model.model.", 12) == 0) memmove(base, base + 6, strlen(base + 6) + 1);
}

static void a_to_b_name(const char *a_name, char *b_name, size_t cap) {
    snprintf(b_name, cap, "%s", a_name);
    char *p = strstr(b_name, ".lora_A.weight");
    if (p) memcpy(p, ".lora_B.weight", 14);
}

static int merge_one(const char *adapter_path, st_index *adapter_idx, const char *out_model_path,
                     st_index *base_idx, const char *a_name, double alpha, double rank_override) {
    char b_name[512], base_name[512];
    tensor_info a_info, b_info, w_info;
    float *a = NULL, *b = NULL, *w = NULL;
    FILE *out = NULL;
    int rc = -1;
    a_to_b_name(a_name, b_name, sizeof(b_name));
    peft_to_base_name(a_name, base_name, sizeof(base_name));
    if (st_find_tensor(adapter_idx, a_name, &a_info) != 0) return 0;
    if (st_find_tensor(adapter_idx, b_name, &b_info) != 0) {
        fprintf(stderr, "missing LoRA B tensor for %s\n", a_name);
        return -1;
    }
    if (st_find_tensor(base_idx, base_name, &w_info) != 0) {
        fprintf(stderr, "missing base tensor %s\n", base_name);
        return -1;
    }
    if (a_info.rank != 2 || b_info.rank != 2 || w_info.rank != 2) {
        fprintf(stderr, "rank mismatch for %s\n", base_name);
        return -1;
    }
    long r = a_info.shape[0], in = a_info.shape[1], out_dim = b_info.shape[0];
    if (b_info.shape[1] != r || w_info.shape[0] != out_dim || w_info.shape[1] != in) {
        fprintf(stderr, "shape mismatch for %s\n", base_name);
        return -1;
    }
    a = read_tensor_as_f32(adapter_path, adapter_idx, &a_info);
    b = read_tensor_as_f32(adapter_path, adapter_idx, &b_info);
    w = read_tensor_as_f32(out_model_path, base_idx, &w_info);
    if (!a || !b || !w) goto done;
    double scale = alpha / (rank_override > 0.0 ? rank_override : (double)r);
    for (long o = 0; o < out_dim; o++) {
        for (long i = 0; i < in; i++) {
            double delta = 0.0;
            for (long k = 0; k < r; k++) delta += (double)b[o * r + k] * (double)a[k * in + i];
            w[o * in + i] += (float)(scale * delta);
        }
    }
    out = fopen(out_model_path, "r+b");
    if (!out) goto done;
    if (write_tensor_from_f32(out, base_idx, &w_info, w) != 0) goto done;
    printf("merged %s\n", base_name);
    rc = 1;
done:
    if (out) fclose(out);
    free(a);
    free(b);
    free(w);
    return rc;
}

static int enumerate_and_merge(const char *adapter_path, st_index *adapter_idx, const char *out_model_path,
                               st_index *base_idx, double alpha, double rank_override) {
    char *p = adapter_idx->header;
    int merged = 0;
    while ((p = strstr(p, ".lora_A.weight\"")) != NULL) {
        char *start = p;
        char name[512];
        size_t len;
        while (start > adapter_idx->header && start[-1] != '"') start--;
        len = (size_t)(p + strlen(".lora_A.weight") - start);
        if (len >= sizeof(name)) return -1;
        memcpy(name, start, len);
        name[len] = 0;
        int rc = merge_one(adapter_path, adapter_idx, out_model_path, base_idx, name, alpha, rank_override);
        if (rc < 0) return -1;
        merged += rc;
        p++;
    }
    return merged;
}

int main(int argc, char **argv) {
    if (argc < 4) {
        fprintf(stderr, "usage: %s <base_model_dir> <adapter_dir> <out_dir> [alpha] [rank]\n", argv[0]);
        return 2;
    }
    const char *base_dir = argv[1];
    const char *adapter_dir = argv[2];
    const char *out_dir = argv[3];
    double alpha = argc > 4 ? atof(argv[4]) : 16.0;
    double rank_override = argc > 5 ? atof(argv[5]) : 0.0;
    char base_model[1024], adapter_model[1024], out_model[1024];
    st_index base_idx = {0}, adapter_idx = {0};
    int merged;
    path_join(base_model, sizeof(base_model), base_dir, "model.safetensors");
    path_join(adapter_model, sizeof(adapter_model), adapter_dir, "adapter_model.safetensors");
    path_join(out_model, sizeof(out_model), out_dir, "model.safetensors");
    if (load_st_index(base_model, &base_idx) != 0) {
        fprintf(stderr, "failed to read base safetensors: %s\n", base_model);
        return 1;
    }
    if (load_st_index(adapter_model, &adapter_idx) != 0) {
        fprintf(stderr, "failed to read adapter safetensors: %s\n", adapter_model);
        free(base_idx.header);
        return 1;
    }
    if (copy_model_dir(base_dir, out_dir) != 0) {
        fprintf(stderr, "failed to copy model dir %s -> %s\n", base_dir, out_dir);
        free(base_idx.header);
        free(adapter_idx.header);
        return 1;
    }
    merged = enumerate_and_merge(adapter_model, &adapter_idx, out_model, &base_idx, alpha, rank_override);
    free(base_idx.header);
    free(adapter_idx.header);
    if (merged <= 0) {
        fprintf(stderr, "no LoRA tensors merged\n");
        return 1;
    }
    printf("merged tensors: %d\noutput: %s\n", merged, out_dir);
    return 0;
}
