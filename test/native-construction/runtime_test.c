/* Exercise the actual freestanding runtime implementation under ASan/UBSan. */
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include NEURX_COMPILER_RUNTIME

NativeBuilder *native_builders;
static void *blocks[10000];
static size_t block_count;
static int check_construction_root;
static int fail_after = -1;
void *alloc(I bytes) {
    if (fail_after == 0) { fail_after = -1; return NULL; }
    if (fail_after > 0) fail_after--;
    if (check_construction_root == 1) {
        assert(native_builders != NULL);
        assert(native_builders->data == NULL);
        check_construction_root = 0;
    } else if (check_construction_root == 2) {
        check_construction_root = 1;
    }
    assert(bytes > 0 && block_count < 10000);
    void *p = calloc(1, (size_t)bytes);
    assert(p);
    blocks[block_count++] = p;
    return p;
}
char *toc(S *value) {
    if (!value || value->n < 0) return NULL;
    char *out = alloc(value->n + 1);
    memcpy(out, value->p, (size_t)value->n);
    return out;
}
S *readfile(S *path) { (void)path; return NULL; }
I run(I *args) { (void)args; return -1; }
char **envp;
static S *text(const char *value) {
    size_t n = strlen(value); S *out = alloc((I)n + 8);
    out->n = (I)n; memcpy(out->p, value, n); return out;
}
static I bits(double value) { union { double f; I i; } x = {.f=value}; return x.i; }
static double *cells(I *array) { return (double *)(array + 1); }
static I *finish(I id, I kind) {
    assert(s_ext_builder_seal(id, kind) == 0);
    I *out = kind == 0 ? s_ext_builder_take_float(id) : kind == 1 ? s_ext_builder_take_int(id) : s_ext_builder_take_string(id);
    assert(out && !s_ext_builder_open(id)); return out;
}
int main(int argc, char **argv) {
    assert(argc == 2);
    assert(s_ext_builder_stats_reset() == 0);
    assert(s_ext_builder_new(-1,0) == -22);
    assert(s_ext_builder_new(1,9) == -22);
    assert(s_ext_builder_new(MAX_I,0) == -75);
    assert(s_ext_builder_set_float(0,0,bits(1)) == -9);
    assert(s_ext_builder_release(-1) == -9);
    I id = s_ext_builder_new(4,0), alias = id;
    assert(id > 0 && s_ext_builder_open(id));
    assert(s_ext_builder_stats_reset() == -16);
    assert(s_ext_builder_take_float(id) == NULL);
    assert(s_ext_builder_set_float(id,-1,bits(9)) == -34);
    assert(s_ext_builder_set_float(id,4,bits(9)) == -34);
    assert(s_ext_builder_set_int(id,0,1) == -22);
    assert(s_ext_builder_set_float(id,1,bits(-2.5)) == 0);
    assert(s_ext_builder_set_float(alias,2,bits(-0.0)) == 0);
    assert(s_ext_builder_seal(id,1) == -22 && s_ext_builder_open(id));
    assert(s_ext_builder_seal(id,0) == 0);
    assert(s_ext_builder_set_float(alias,1,bits(10)) == -114);
    assert(s_ext_builder_seal(id,0) == -114);
    assert(s_ext_builder_take_int(id) == NULL); /* Wrong take does not consume. */
    I *array = s_ext_builder_take_float(id);
    assert(array && array[0] == 4 && cells(array)[0] == 0 && cells(array)[1] == -2.5 && signbit(cells(array)[2]));
    assert(s_ext_builder_take_float(alias) == NULL);
    assert(s_ext_builder_set_float(alias,0,bits(3)) == -9);
    assert(s_ext_builder_release(alias) == -9);
    assert(cells(array)[1] == -2.5);
    assert(s_ext_builder_stats(0) == 2 && s_ext_builder_stats(3) == 0 && s_ext_builder_stats(4) == 2 && s_ext_builder_stats(5) == 0);
    id=s_ext_builder_new(0,0);assert(id>0);assert(finish(id,0)[0]==0);
    id=s_ext_builder_new(2,1);assert(s_ext_builder_set_int(id,1,MAX_I)==0);assert(finish(id,1)[2]==MAX_I);
    id=s_ext_builder_new(2,2);S *word=text("retained");assert(s_ext_builder_set_string(id,1,word)==0);assert((S *)finish(id,2)[2]==word);
    id=s_ext_builder_new(4,0);assert(s_ext_builder_fill_float(id,bits(3.25))==0);
    assert(s_ext_builder_copy_float(id,1,array)==-34);
    assert(s_ext_builder_copy_float(id,0,array)==0);
    I *copy=finish(id,0);assert(cells(copy)[1]==-2.5);
    I *slice=s_ext_float_slice(copy,1,2);assert(slice && slice[0]==2 && cells(slice)[0]==-2.5);
    I *patched=s_ext_float_patch(copy,0,slice);assert(patched && cells(patched)[0]==-2.5 && cells(copy)[0]==0);
    assert(s_ext_float_slice(copy,3,2)==NULL && s_ext_float_patch(copy,4,slice)==NULL);
    I raw_bytes[]={4,65,0,255,257}; S *converted=s_ext_bytes_string(raw_bytes);
    assert(converted->n==4 && converted->p[0]==65 && converted->p[1]==0 && converted->p[2]==255 && converted->p[3]==1);
    for(int i=0;i<100;i++){I handle=s_ext_builder_new(32,0);assert(handle>0);assert(s_ext_builder_release(handle)==0);assert(s_ext_builder_release(handle)==-9);}
    assert(s_ext_builder_stats(5)==0);
    /* Force the allocator shim to inspect the descriptor root before backing allocation. */
    I previous_calls=(I)block_count; (void)previous_calls;
    check_construction_root = 2;
    id=s_ext_builder_new(4,0); assert(id>0 && check_construction_root==0);assert(s_ext_builder_release(id)==0);

    const unsigned char bf16[]={0,0,0,128,128,63,128,191,1,0,128,127,192,127};
    FILE *file=fopen(argv[1],"wb");assert(file);assert(fwrite(bf16,1,sizeof(bf16),file)==sizeof(bf16));assert(fclose(file)==0);
    S *path=text(argv[1]);
    id=s_ext_tensor_read(path,0,7,1);assert(id>0);I *decoded=finish(id,0);
    assert(decoded[0]==7 && cells(decoded)[0]==0 && signbit(cells(decoded)[1]));
    assert(cells(decoded)[2]==1 && cells(decoded)[3]==-1 && cells(decoded)[4]==ldexp(1.,-133));
    assert(isinf(cells(decoded)[5]) && isnan(cells(decoded)[6]));
    assert(s_ext_tensor_read(path,0,8,1)==-61);
    assert(s_ext_tensor_read(path,MAX_I,1,0)==-75);
    assert(s_ext_tensor_read(path,0,1,9)==-22);
    id=s_ext_tensor_read(path,2,0,1);assert(id>0 && finish(id,0)[0]==0);
    const unsigned char f16[]={1,0,0,128,0,60,0,124,0,126};
    file=fopen(argv[1],"wb");assert(file);assert(fwrite(f16,1,sizeof(f16),file)==sizeof(f16));fclose(file);
    id=s_ext_tensor_read(path,0,5,2);assert(id>0);decoded=finish(id,0);
    assert(cells(decoded)[0]==ldexp(1.,-24) && signbit(cells(decoded)[1]) && cells(decoded)[2]==1);
    assert(isinf(cells(decoded)[3]) && isnan(cells(decoded)[4]));
    const uint32_t f32[]={0x3f800000,0x80000000,1,0x7f800000,0x7fc00000};
    file=fopen(argv[1],"wb");assert(file);assert(fwrite(f32,1,sizeof(f32),file)==sizeof(f32));fclose(file);
    id=s_ext_tensor_read(path,0,5,0);assert(id>0);decoded=finish(id,0);
    assert(cells(decoded)[0]==1 && signbit(cells(decoded)[1]) && cells(decoded)[2]==ldexp(1.,-149));
    assert(isinf(cells(decoded)[3]) && isnan(cells(decoded)[4]));
    assert(s_ext_builder_stats(5)==0);
    /* Fault injection validates the real runtime's failure cleanup, not inference. */
    fail_after=0;assert(s_ext_builder_new(4,0)==-12);assert(native_builders==NULL);
    fail_after=1;assert(s_ext_builder_new(4,0)==-12);assert(native_builders==NULL);
    assert(s_ext_builder_stats(5)==0);
    file=fopen(argv[1],"wb");assert(file);fclose(file);
    id=s_ext_tensor_read(path,0,0,1);assert(id>0 && finish(id,0)[0]==0);
    assert(s_ext_tensor_read(path,0,1,1)==-61);
    assert(s_ext_tensor_read(text("/neurx/nonexistent-file"),0,0,1)==-2);
    assert(s_ext_tensor_read(text("."),0,1,1)<0);
    assert(s_ext_builder_stats(5)==0);
    native_builder_next_id=MAX_I;
    id=s_ext_builder_new(1,0);assert(id==MAX_I);assert(s_ext_builder_new(1,0)==-75);assert(s_ext_builder_release(id)==0);
    assert(s_ext_builder_stats_reset()==0);
    for(size_t i=0;i<block_count;i++)free(blocks[i]);
    puts("native builder safety, lifecycle, bulk IEEE decode and errors: PASS");
    return 0;
}
