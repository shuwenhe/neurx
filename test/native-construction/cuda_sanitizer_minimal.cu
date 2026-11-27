#include <cuda_runtime.h>
#include <cstdio>
#include <cstring>
__global__ void fill(int* values) { values[threadIdx.x] = threadIdx.x + 1; }
__global__ void oob(int* values) { values[32] = 123; }
__global__ void uninitialized(const int* source,int* target) { target[0] = source[0]; }
int main(int argc,char** argv) {
  int* values=nullptr; int host[32]={};
  auto check=[](cudaError_t e){ if(e!=cudaSuccess){std::fprintf(stderr,"CUDA ERROR: %s\n",cudaGetErrorString(e));return false;}return true;};
  if(!check(cudaMalloc(&values,sizeof(host))))return 1;
  bool negative=argc==2;
  int* source=nullptr;
  if(negative && !std::strcmp(argv[1],"--oob")) { fill<<<1,32>>>(values);oob<<<1,1>>>(values); }
  else if(negative && !std::strcmp(argv[1],"--uninitialized")) {
    if(!check(cudaMalloc(&source,sizeof(int))))return 5;
    fill<<<1,32>>>(values);uninitialized<<<1,1>>>(source,values);
  } else if(negative)return 6;
  else fill<<<1,32>>>(values);
  if(!check(cudaGetLastError()) || !check(cudaDeviceSynchronize()) ||
     !check(cudaMemcpy(host,values,sizeof(host),cudaMemcpyDeviceToHost)))return 2;
  if(!check(cudaFree(values)))return 3;
  if(source && !check(cudaFree(source)))return 7;
  if(negative){std::puts("CUDA_NEGATIVE_CONTROL_FINISHED");return 0;}
  for(int i=0;i<32;++i)if(host[i]!=i+1)return 4;
  std::puts("CUDA_MINIMAL_PASS");
}
