#include "read_write_mrc.h"
#include "atom.h"
#include <iostream>
#include <cuda_runtime.h>
#include <sys/time.h>
#include "file_read_write.cu"
#include "sirt.cu"
//#include "mace.cu"

#define FALSE 0
#define TRUE 1
#define checkCudaErrors( a ) do { \
	if (cudaSuccess != (a)) { \
	fprintf(stderr, "Cuda runtime error in line %d of file %s \
	: %s \n", __LINE__, __FILE__, cudaGetErrorString(cudaGetLastError()) ); \
	exit(EXIT_FAILURE); \
	} \
	} while(0);
using namespace std;

double iStart,iElaps;

int ITER_NUM = 4;
float SIRT_STEP_LENGTH = 0.2;
float MACE_STEP_LENGTH = 0.5;
int file_num=2;
int NCC_FLAG = 0;

void check_GPU_mem()
{
	size_t avail;
	size_t total;
	cudaMemGetInfo(&avail,&total);
	size_t used = total - avail;
	printf("Used:%zu /Total:%zu --%f   Rest:%zu\n",used,total,(float)used/total,avail);
}

double cpuSecond(){
	struct timeval tp;
	gettimeofday(&tp,NULL);
	//sce + msec
	return (double)tp.tv_sec +(double )tp.tv_usec*1e-6;
}

long long  vol_pixel_num, * PrjXYAngN;
int iLenx = 8,iLeny = 8,iLenz = 8; 

void copyOnCPU(float *tar,float *sou,long long l)
{
	for(long long k=0;k<l;k++)
	{
		tar[k] = sou[k];
	}
}


int main(int argc,char *argv[])
{
	iStart = cpuSecond();

/************************select device*****************************/
//	cudaSetDevice(0);
//	check_GPU_mem();
/********************************************************************/


/**************************read parameter **********/
	char * out_addr;
	char ** in_addr;
	char ** txbr_addr;

	for(int i=0;i<argc;i++)
	{
		if(!strcmp("-lx",argv[i])) iLenx = atoi(argv[i+1]);
		if(!strcmp("-ly",argv[i])) iLeny = atoi(argv[i+1]);
		if(!strcmp("-lz",argv[i])) iLenz = atoi(argv[i+1]);
		if(!strcmp("-ncc",argv[i])) NCC_FLAG = atoi(argv[i+1]);
		if(!strcmp("-n",argv[i])) ITER_NUM = atoi(argv[i+1]);
		if(!strcmp("-s",argv[i])) SIRT_STEP_LENGTH = atof(argv[i+1]);
		if(!strcmp("-m",argv[i])) MACE_STEP_LENGTH = atof(argv[i+1]);
		if(!strcmp("-of",argv[i])) out_addr = argv[i+1];
		if(!strcmp("-fn",argv[i]))
		{
			file_num = atoi(argv[i+1]);
			in_addr = (char **)malloc(sizeof(char *)*file_num);
			txbr_addr = (char **)malloc(sizeof(char *)*file_num);
			for(int j=0;j<file_num;j++)
			{
				in_addr[j] = argv[i+2+j*2];
				txbr_addr[j] = argv[i+3+j*2];
			}
		}
	}
	
	printf("TOTAL iterate times:%d\n",ITER_NUM);
	printf("OUT file address:%s\n",out_addr);
	//for(int i=0;i<file_num;i++) printf("%s \n",in_addr[i]);
/*************************Malloc data space and Read head data************************/
	Volume *vol;
	Projection **prj = (Projection **)malloc(sizeof(Projection)*file_num);
	MrcHeader **in_head = (MrcHeader **)malloc(sizeof(MrcHeader)*file_num);
	MrcHeader *out_head;
	cudaMallocManaged((void **)&vol,sizeof(Volume));
	cudaMallocManaged((void **)&out_head,sizeof(MrcHeader));
	for(int i=0;i<file_num;i++)
	{
		cudaMallocManaged((void **)&prj[i],sizeof(Projection));
		cudaMallocManaged((void **)&in_head[i],sizeof(MrcHeader));
	}
	vol->Xstart = INF;
	vol->Xend = -INF;
	vol->Ystart = INF;
	vol->Yend = -INF;
	vol->Zstart = INF;
	vol->Zend = -INF;

	for(int i=0;i<file_num;i++)
		read_head_data(prj[i],in_head[i],in_addr[i]);
/******************************************************************************/

/********************read txbr file**********************************************/
	double **x_coef = (double **)malloc(sizeof(double *)*file_num);
	double **y_coef = (double **)malloc(sizeof(double *)*file_num);	

	for(int i=0;i<file_num;i++)
	{
		cudaMallocManaged((void **)&x_coef[i],sizeof(double)*prj[i]->AngN*10);
		memset(x_coef[i], 0 , sizeof(double)*prj[i]->AngN*10);
		//printf("%d",sizeof(double)*prj->AngN*10);
		cudaMallocManaged((void **)&y_coef[i],sizeof(double)*prj[i]->AngN*10);
		memset(y_coef[i], 0 , sizeof(double)*prj[i]->AngN*10);
	
		read_txbr_data(vol,x_coef[i],y_coef[i],txbr_addr[i]);	
	}
	vol->X = vol->Xend - vol->Xstart;
	vol->Y = vol->Yend - vol->Ystart;
	vol->Z = vol->Zend - vol->Zstart;
	printf("xs:%d xe:%d x:%d\n",vol->Xstart,vol->Xend,vol->X);
	printf("ys:%d ye:%d y:%d\n",vol->Ystart,vol->Yend,vol->Y);
	printf("zs:%d ze:%d z:%d\n",vol->Zstart,vol->Zend,vol->Z);
/*************************************************************/


/*************read all data*************************************************/
	float **prj_real = (float **)malloc(sizeof(float *)*file_num);
	vol_pixel_num = vol->X*(long long)vol->Y*vol->Z;
	printf("vol_pixel_num:%lld\n",vol_pixel_num);
	PrjXYAngN = (long long *)malloc(sizeof(long long)*file_num);
	long long PrjXYA =  -1;
	/*for input file*/
	for(int i=0;i<file_num;i++)
	{	
		PrjXYAngN[i] = prj[i]->X*(long long)prj[i]->Y*prj[i]->AngN;
		PrjXYA = max(PrjXYA,PrjXYAngN[i]);
	//	printf("%d PrjXYAngN:%lld\n",i,PrjXYAngN[i]);
		prj_real[i] = (float *)malloc(sizeof(float)*PrjXYAngN[i]);
		//checkCudaErrors(cudaMallocManaged((void **)&prj_real[i],sizeof(float)*PrjXYAngN[i]));
		memset(prj_real[i], 0 , sizeof(float)*PrjXYAngN[i]);
		read_all_data(in_head[i],prj_real[i], in_addr[i]);
	}
/*******************************************************************/

/*****************************initial model*****************************/
	float **w_data = (float **)malloc(sizeof(float)*vol_pixel_num*file_num);
	float *z_data;
	float *v_data;
	for(int i=0;i<file_num;i++)
	{
		w_data[i] = (float *)malloc(sizeof(float)*vol_pixel_num);
	//	cudaMallocManaged((void **)&w_data[i],sizeof(float)*vol_pixel_num);
	}	
	cudaMallocManaged((void **)&z_data,sizeof(float)*vol_pixel_num);
	cudaMallocManaged((void **)&v_data,sizeof(float)*vol_pixel_num);

	float *vol_real;
	cudaMallocManaged((void **)&vol_real,sizeof(float)*vol_pixel_num);
	dim3 block(iLenx,iLeny,iLeny);
	dim3 grid_vol((vol->X+block.x-1)/block.x,(vol->Y+block.y-1)/block.y,(vol->Z+block.z-1)/block.z);
	
	float *dprj_real;
	checkCudaErrors(cudaMallocManaged((void **)&dprj_real,sizeof(float)*PrjXYA));
	for(long long k=0;k<PrjXYAngN[0];k++) dprj_real[k] = prj_real[0][k];

	backProjOnGPU<<<grid_vol,block>>>(prj[0],vol,x_coef[0],y_coef[0],dprj_real,vol_real,1);
	cudaDeviceSynchronize();
	for(int i=0;i<file_num;i++)	for(long long k=0;k<vol_pixel_num;k++) w_data[i][k] = vol_real[k];
/*************************************************************************/
	iElaps = cpuSecond()-iStart;
	printf("Host time elapsed:%lfsec\n",iElaps);	
/**********************************************IERTATION***************/
	float *dw_data;
	checkCudaErrors(cudaMallocManaged((void **)&dw_data,sizeof(float)*vol_pixel_num));
	for(int i=0;i<ITER_NUM;i++)
	{
		for(int j=0;j<file_num;j++)
		{
			copyOnCPU(dw_data,w_data[j],vol_pixel_num);
			copyOnCPU(dprj_real,prj_real[j],PrjXYAngN[j]);
			
			//initial data
			initial_zdata<<<grid_vol,block>>>(vol_real,dw_data,z_data,vol);
			cudaDeviceSynchronize();
			//sirt
			dim3 grid_prj((prj[j]->X+block.x-1)/block.x,(prj[j]->Y+block.y-1)/block.y,(prj[j]->AngN+block.z-1)/block.z);
			float *iter_prj_divisor,*iter_prj_dividend;
			checkCudaErrors(cudaMallocManaged((void **)&iter_prj_divisor,sizeof(float)*PrjXYAngN[j]));
			checkCudaErrors(cudaMallocManaged((void **)&iter_prj_dividend,sizeof(float)*PrjXYAngN[j]));	
			memset(iter_prj_divisor,0,sizeof(float)*PrjXYAngN[j]);
			memset(iter_prj_dividend,0,sizeof(float)*PrjXYAngN[j]);
			reProjOnGPU<<<grid_vol,block>>>(prj[j],vol,x_coef[j],y_coef[j],z_data,iter_prj_divisor,iter_prj_dividend);
			cudaDeviceSynchronize();
			computePrjError<<<grid_prj,block>>>(prj[j],dprj_real,iter_prj_divisor,iter_prj_dividend);
			copyDataOnGPU<<<grid_vol,block>>>(v_data,z_data,vol);
			cudaDeviceSynchronize();
			backProjOnGPU<<<grid_vol,block>>>(prj[j],vol,x_coef[j],y_coef[j],iter_prj_divisor,v_data,SIRT_STEP_LENGTH);
			cudaDeviceSynchronize();
			//check_GPU_mem();
			
			//mace
			maceOnGPU<<<grid_vol,block>>>(v_data,dw_data,z_data,vol,MACE_STEP_LENGTH);	
			//copyDataOnGPU<<<grid_vol,block>>>(dw_data,v_data,vol);
			cudaDeviceSynchronize();
			copyOnCPU(w_data[j],dw_data,vol_pixel_num);
		
			cudaFree(iter_prj_divisor);
			cudaFree(iter_prj_dividend);
		} 
		for(long long k=0;k<vol_pixel_num;k++)
		{
			vol_real[k] = 0;
			for(int j=0;j<file_num;j++) vol_real[k] += w_data[j][k];
			vol_real[k] /= file_num;
		}
		printf("Iteration %d finished..\n",i);
	}

/*****************************************************************************/
	iElaps = cpuSecond()-iStart;
	printf("Host time elapsed:%lfsec\n",iElaps);

/**********************  NCC  ************************************************/	
	if(NCC_FLAG)
	{
		float *iter_prj_divisor,*iter_prj_dividend;
		int j=0;
		checkCudaErrors(cudaMallocManaged((void **)&iter_prj_divisor,sizeof(float)*PrjXYAngN[j]));
		checkCudaErrors(cudaMallocManaged((void **)&iter_prj_dividend,sizeof(float)*PrjXYAngN[j]));	
		memset(iter_prj_divisor,0,sizeof(float)*PrjXYAngN[j]);
		memset(iter_prj_dividend,0,sizeof(float)*PrjXYAngN[j]);
		reProjOnGPU<<<grid_vol,block>>>(prj[j],vol,x_coef[j],y_coef[j],z_data,iter_prj_divisor,iter_prj_dividend);
		cudaDeviceSynchronize();
		for(int k=0;k<PrjXYAngN[j];k++) if(iter_prj_dividend[k]!=0) iter_prj_divisor[k]/=iter_prj_dividend[k];

		double NCC_res[121];
		int prj_size = prj[j]->X*prj[j]->Y;
		for(int z=0;z<121;z++)
		{
			int st = prj_size*z;
			int ed = prj_size*(z+1);
			double mean1=0,mean2=0;
			for(int k=st;k<ed;k++)
			{
				mean1+=iter_prj_divisor[k];
				mean2+=prj_real[j][k];
			}
			mean1/=prj_size;
			mean2/=prj_size;
			double divisor=0;
			double dividend1=0,dividend2=0;
			for(int k=st;k<ed;k++)
			{
				divisor+=(iter_prj_divisor[k]-mean1)*(prj_real[j][k]-mean2);
				dividend1+=(iter_prj_divisor[k]-mean1)*(iter_prj_divisor[k]-mean1);
				dividend2+=(prj_real[j][k]-mean2)*(prj_real[j][k]-mean2);
			}
			NCC_res[z]=divisor/(sqrt(dividend1)*sqrt(dividend2));
		}
		printf("NCC result for %d iterations:\n",ITER_NUM);
		for(int z=0;z<121;z++) printf("%lf\n",NCC_res[z]);
	}
/*****************************************************************************/	


/***************************OUTPUT file******************************/
	mrc_init_head(out_head);
	set_head(out_head,vol);
	printf("OUT head:%d %d %d 0\n",out_head->nx,out_head->ny,out_head->nz);
	update_head(vol_real,out_head);
	write_data(out_addr,out_head,vol_real);

/*******************************************************************/

	cudaDeviceReset();//重置CUDA设备释放程序占用的资源

	iElaps = cpuSecond()-iStart;
	printf("Host time elapsed:%lfsec\n",iElaps);
	return 0;
}


