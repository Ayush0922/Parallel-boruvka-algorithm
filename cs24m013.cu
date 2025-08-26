#include <algorithm>
#include <iostream>
#include <vector>
#include <string>
#include <cuda_runtime.h>
#include <chrono>

using namespace std;

#define MOD 1000000007


__global__ void reset_cheapest(volatile int* cheapest,volatile int* cheapest2, int V) {
int tid = blockDim.x * blockIdx.x + threadIdx.x;
if (tid < V) {
cheapest2[tid] = -1;
cheapest[tid] = 100000;
}
}

__global__ void reset_claim(volatile int* claim, int E) {
int tid = blockDim.x * blockIdx.x + threadIdx.x;
if (tid < E) {
claim[tid] = 0;
}
}



__device__ int my_strcmp(const char* a, const char* b) {
int i = 0;
while (a[i]&&b[i] && a[i]==b[i]){
i++;
}
return a[i] - b[i];
}

__global__ void setter(int*d_w,char** d_type, int e){
int tid = blockDim.x*blockIdx.x + threadIdx.x;
if(tid>=e) return;
if(my_strcmp(d_type[tid], "normal") == 0){
return;
}
else if(my_strcmp(d_type[tid], "dept") == 0){
d_w[tid]*=3;
}
else if(my_strcmp(d_type[tid], "green") == 0){
d_w[tid]*=2;
}
else{
d_w[tid]*=5;
}
}

__global__ void set2(volatile int* parent, volatile int* size,volatile int* cheapest,volatile int* cheap2,volatile int* claim,volatile int* mstw, volatile int* nc , int V) {
int tid = blockDim.x*blockIdx.x + threadIdx.x;
if(tid>=V) return;
if(tid==0){
*mstw = 0;     
*nc = V; 
}
parent[tid] = tid;
size[tid] = 1;
cheapest[tid] = 100000;
cheap2[tid] = -1;
//claim[tid] = 0;
}


__device__ int find(volatile int* parent, int i) {

int root = i;
int current;
do{
current = root;
root = atomicAdd((int*)&parent[current], 0);  
}while (current != root);
    
// Path compression
while (i != root) {
int next = atomicAdd((int*)&parent[i], 0);
atomicExch((int*)&parent[i], root);   
i = next;
}
return root;

}

__global__ void cefev(volatile int* parent,int* s,int* d,int* w,volatile int* cheapest,int e) {

int tid = blockDim.x*blockIdx.x + threadIdx.x;
if(tid>=e) return;    

int src = s[tid];
int dest = d[tid];
int weight =  w[tid];
    
int set1 = find(parent, src);
int set2 = find(parent, dest);

if(set1 != set2) {
if(cheapest[set1]>weight) {
atomicMin((int*)&cheapest[set1], weight);  
}
if(cheapest[set2]>weight) {
atomicMin((int*)&cheapest[set2], weight); 
}
}
}

__global__ void cefev2(volatile int* parent,int* s,int* d,int* w,volatile int* cheapest,volatile int* cheapest2,int e) {

int tid = blockDim.x*blockIdx.x + threadIdx.x;
if(tid>=e) return;    

int src = s[tid];
int dest = d[tid];
int weight =  w[tid];
    
int set1 = find(parent, src);
int set2 = find(parent, dest);

if(set1 != set2) {
if(cheapest[set1]==weight) {
atomicExch((int*)&cheapest2[set1], tid);
}
if(cheapest[set2]==weight) {
atomicExch((int*)&cheapest2[set2], tid);
}
}
}


__global__ void mk(volatile int* parent,volatile int* size,int* s,int* d,int* w,volatile int* cheap2,volatile int* claim,volatile int* mst_weight,volatile int* num_comp,int V) {

int tid = blockDim.x * blockIdx.x + threadIdx.x;
if (tid >= V) return;

int edge_id = cheap2[tid];
if (edge_id == -1) return;

if (atomicCAS((int*)&claim[edge_id], 0, 1) != 0) return;
int src = s[edge_id];
int dest = d[edge_id];
int weight = w[edge_id];

int set1 = find(parent, src);
int set2 = find(parent, dest);

if (set1 == set2) {
atomicExch((int*)&claim[edge_id], 0);
return;
}

int size1 = atomicAdd((int*)&size[set1], 0);
int size2 = atomicAdd((int*)&size[set2], 0);

bool merged = false;

if (size1 < size2) {
// Attempt to merge set1 into set2
int current_parent = atomicAdd((int*)&parent[set1], 0);
if (current_parent == set1 && atomicCAS((int*)&parent[set1], set1, set2) == set1) {
atomicAdd((int*)&size[set2], size1);
merged = true;
}
} 
else {
// Attempt to merge set2 into set1
int current_parent = atomicAdd((int*)&parent[set2], 0);
if (current_parent == set2 && atomicCAS((int*)&parent[set2], set2, set1) == set2) {
atomicAdd((int*)&size[set1], size2);
merged = true;
}
}
if (merged) {
atomicAdd((int*)mst_weight, weight);
atomicSub((int*)num_comp, 1);
} 
else{
atomicExch((int*)&claim[edge_id], 0);
 }
}
    


int main(){
 
int v, e;
cin >> v >> e;

vector<int> s;
vector<int> d;
vector<int> w;
vector<string> type;
vector<int> parent;
vector<int> size;

for(int i=0;i<e;i++){
int u,v,wt;
string t;
cin>>u>>v>>wt>>t;
s.push_back(u);
d.push_back(v);
w.push_back(wt);
type.push_back(t);
}
int mstw =0;
int* d_s;
int* d_d;
int* d_w;
char** d_type;
volatile int* d_parent;
volatile int* d_size;
volatile int* d_cheap;
volatile int* d_cheap2;
volatile int* d_claim;
volatile int* d_mstw;
volatile int* d_nc;
cudaMalloc((void**)&d_parent, v*sizeof(int));
cudaMalloc((void**)&d_size, v*sizeof(int));
cudaMalloc((void**)&d_cheap, v*sizeof(int));
cudaMalloc((void**)&d_cheap2, v*sizeof(int));
cudaMalloc((void**)&d_claim, e*sizeof(int));
cudaMalloc((void**)&d_mstw, sizeof(int));
cudaMalloc((void**)&d_nc, sizeof(int));
cudaMalloc(&d_s,e*sizeof(int));
cudaMalloc(&d_d,e*sizeof(int));
cudaMalloc(&d_w,e*sizeof(int));
cudaMalloc(&d_type,e*sizeof(char*));
cudaMemcpy(d_s, s.data(), e*sizeof(int), cudaMemcpyHostToDevice);
cudaMemcpy(d_d, d.data(), e*sizeof(int), cudaMemcpyHostToDevice);
cudaMemcpy(d_w, w.data(), e*sizeof(int), cudaMemcpyHostToDevice);
char** h_type = new char*[e];
for(int i=0;i<e;i++) {
cudaMalloc(&h_type[i], type[i].size() + 1);
cudaMemcpy(h_type[i], type[i].c_str(), type[i].size() + 1, cudaMemcpyHostToDevice);
}
cudaMemcpy(d_type, h_type, e * sizeof(char*), cudaMemcpyHostToDevice);

int psb = ceil(e/1024.0);
int s2b = ceil(v/1024.0);
int nc = v;

auto start = std::chrono::high_resolution_clock::now(); // keep it just before the kernel launch
set2<<<s2b,1024>>>(d_parent, d_size,d_cheap,d_cheap2,d_claim,d_mstw,d_nc,v);
setter<<<psb,1024>>>(d_w,d_type,e);
//cudaDeviceSynchronize();
while(nc>1){
reset_cheapest<<<s2b, 1024>>>(d_cheap,d_cheap2, v);
reset_claim<<<psb, 1024>>>(d_claim, e);
//cudaDeviceSynchronize();
cefev<<<psb,1024>>>(d_parent,d_s,d_d,d_w,d_cheap,e);
//cudaDeviceSynchronize();
cefev2<<<psb,1024>>>(d_parent,d_s,d_d,d_w,d_cheap,d_cheap2,e);
//cudaDeviceSynchronize();
mk<<<s2b,1024>>>(d_parent,d_size,d_s,d_d,d_w,d_cheap2,d_claim,d_mstw,d_nc,v);
//cudaDeviceSynchronize();
cudaMemcpy(&nc,(void*)d_nc,sizeof(int),cudaMemcpyDeviceToHost);
}
cudaDeviceSynchronize();
auto end = std::chrono::high_resolution_clock::now(); // keep it just after the kernel launch
cudaMemcpy(&mstw,(void*)d_mstw,sizeof(int),cudaMemcpyDeviceToHost);
cout<<mstw%MOD<<"\n";
std::chrono::duration<double> elapsed1 = end - start;
//cout<< elapsed1.count() << "\n";
for (int i = 0; i < e; i++) {
cudaFree(h_type[i]);
}    
delete[] h_type;
cudaFree(d_s);
cudaFree(d_d);
cudaFree(d_w);
cudaFree(d_type);
cudaFree((void*)d_parent);
cudaFree((void*)d_size);
cudaFree((void*)d_cheap);
cudaFree((void*)d_cheap2);
cudaFree((void*)d_claim);
cudaFree((void*)d_mstw);
cudaFree((void*)d_nc);

return 0;
}

