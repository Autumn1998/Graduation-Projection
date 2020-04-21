#include <cuda_runtime.h>
#include <sys/time.h>
#include <stdio.h>

//texture<double,2,cudaReadModeElementType> tex_x;
//texture<double,2,cudaReadModeElementType> tex_y;

__global__ void backProjOnGPU(Projection *prj,Volume *vol,double *x_coef,double *y_coef,float *prj_real,float *vol_real,float iter_step_length)
{
	double divisor;//分子
	double dividend;//分母
	int x = threadIdx.x+blockIdx.x*blockDim.x +vol->Xstart;
	int y = threadIdx.y+blockIdx.y*blockDim.y +vol->Ystart;
	int z = threadIdx.z+blockIdx.z*blockDim.z +vol->Zstart;
	//printf("%d %d\n ",y,z);
	if(x>=vol->Xend || y>=vol->Yend ||z>=vol->Zend) return;
	divisor = 0;
	dividend = 0;
	int index,angle,n;

	for(angle=0;angle<prj->AngN;angle++)
	{
		double res_x,res_y,x_min_del,y_min_del;
		int id = 4*angle,x_min,y_min;	
		res_x = x_coef[id]+x_coef[id+1]*x+x_coef[id+2]*y+x_coef[id+3]*z;
		res_y = y_coef[id]+y_coef[id+1]*x+y_coef[id+2]*y+y_coef[id+3]*z;	
		x_min = floor(res_x);
		y_min = floor(res_y);
		x_min_del = res_x - x_min;
		y_min_del = res_y - y_min;
	
		if(x_min>=0 && x_min<prj->X && y_min>=0 && y_min<prj->Y)//(x_min,y_min)
		{
			n = x_min + y_min*prj->X + angle*prj->X*prj->Y;
			divisor += (1-x_min_del)*(1-y_min_del)*prj_real[n];
			dividend += (1-x_min_del)*(1-y_min_del);
		}
		if(x_min+1>=0 && x_min+1<prj->X && y_min>=0 && y_min<prj->Y)//(x_min+1,y_min)
		{
			n = (x_min+1) + y_min*prj->X + angle*prj->X*prj->Y;
			divisor += x_min_del*(1-y_min_del)*prj_real[n];
			dividend += x_min_del*(1-y_min_del);
		}
		if(x_min>=0 && x_min<prj->X && y_min+1>=0 && y_min+1<prj->Y)//(x_min,y_min+1)
		{
			n = x_min + (y_min+1)*prj->X + angle*prj->X*prj->Y;
			divisor += (1-x_min_del)*y_min_del*prj_real[n];
			dividend += (1-x_min_del)*y_min_del;
		}
		if(x_min+1>=0 && x_min+1<prj->X && y_min+1>=0 && y_min+1<prj->Y)//(x_min+1,y_min+1)
		{
			n = (x_min+1)+ (y_min+1)*prj->X + angle*prj->X*prj->Y;
			divisor += x_min_del*y_min_del*prj_real[n];
			dividend += x_min_del*y_min_del;
		}
	}
	if(dividend!=0.0f)
	{
		index = (x-vol->Xstart)+(y-vol->Ystart)*vol->X+(z-vol->Zstart)*vol->X*vol->Y;
		vol_real[index] += (float)(divisor/dividend)*iter_step_length;
	}
}

__global__ void reProjOnGPU(Projection *prj,Volume *vol,double *x_coef,double *y_coef,float *vol_real,float *iter_prj_divisor,float *iter_prj_dividend)
{
	
	int x = threadIdx.x+blockIdx.x*blockDim.x +vol->Xstart;
	int y = threadIdx.y+blockIdx.y*blockDim.y +vol->Ystart;
	int z = threadIdx.z+blockIdx.z*blockDim.z +vol->Zstart;
	//printf("%d %d\n ",y,z);
	if(x>=vol->Xend || y>=vol->Yend ||z>=vol->Zend) return;	
	int index,angle,n;
	index = (x-vol->Xstart)+(y-vol->Ystart)*vol->X+(z-vol->Zstart)*vol->X*vol->Y;
	
	for(angle=0;angle<prj->AngN;angle++)
	{
		double res_x,res_y,x_min_del,y_min_del;
		int id = 4*angle,x_min,y_min;	
		res_x = x_coef[id]+x_coef[id+1]*x+x_coef[id+2]*y+x_coef[id+3]*z;
		res_y = y_coef[id]+y_coef[id+1]*x+y_coef[id+2]*y+y_coef[id+3]*z;	
		x_min = floor(res_x);
		y_min = floor(res_y);
		x_min_del = res_x - x_min;
		y_min_del = res_y - y_min;
		
		if(x_min>=0 && x_min<prj->X && y_min>=0 && y_min<prj->Y)//(x_min,y_min)
		{
			n = x_min + y_min*prj->X + angle*prj->X*prj->Y;
			atomicAdd(&iter_prj_divisor[n], (1-x_min_del)*(1-y_min_del)*vol_real[index]);
			atomicAdd(&iter_prj_dividend[n], (1-x_min_del)*(1-y_min_del));
		}
		if(x_min+1>=0 && x_min+1<prj->X && y_min>=0 && y_min<prj->Y)//(x_min+1,y_min)
		{
			n = (x_min+1) + y_min*prj->X + angle*prj->X*prj->Y;
			atomicAdd(&iter_prj_divisor[n], x_min_del*(1-y_min_del)*vol_real[index]);
			atomicAdd(&iter_prj_dividend[n], x_min_del*(1-y_min_del));
		}
		if(x_min>=0 && x_min<prj->X && y_min+1>=0 && y_min+1<prj->Y)//(x_min,y_min+1)
		{
			n = x_min + (y_min+1)*prj->X + angle*prj->X*prj->Y;
			atomicAdd(&iter_prj_divisor[n], (1-x_min_del)*y_min_del*vol_real[index]);
			atomicAdd(&iter_prj_dividend[n], (1-x_min_del)*y_min_del);
		}
		if(x_min+1>=0 && x_min+1<prj->X && y_min+1>=0 && y_min+1<prj->Y)//(x_min+1,y_min+1)
		{
			n = (x_min+1)+ (y_min+1)*prj->X + angle*prj->X*prj->Y;
			atomicAdd(&iter_prj_divisor[n], x_min_del*y_min_del*vol_real[index]);
			atomicAdd(&iter_prj_dividend[n], x_min_del*y_min_del);
		}
	}
}


__global__ void computePrjError(Projection *prj,float *prj_real,float *iter_prj_divisor,float *iter_prj_dividend)
{
	int x = threadIdx.x+blockIdx.x*blockDim.x;
	int y = threadIdx.y+blockIdx.y*blockDim.y;
	int z = threadIdx.z+blockIdx.z*blockDim.z;
	if(x>=prj->X || y>=prj->Y ||z>=prj->AngN) return;
	int index;	
	index = x+y*prj->X+z*prj->X*prj->Y;
	if(iter_prj_dividend[index]!=0)
		iter_prj_divisor[index] /= iter_prj_dividend[index];
	iter_prj_divisor[index] = prj_real[index]-iter_prj_divisor[index];
}

__global__ void copyDataOnGPU(float *tar,float *sou,Volume *vol)
{
	int x = threadIdx.x+blockIdx.x*blockDim.x+vol->Xstart;
	int y = threadIdx.y+blockIdx.y*blockDim.y+vol->Ystart;
	int z = threadIdx.z+blockIdx.z*blockDim.z+vol->Zstart;
	//printf("%d %d\n ",y,z);
	if(x>=vol->Xend || y>=vol->Yend ||z>=vol->Zend) return;	
	int index = (x-vol->Xstart)+(y-vol->Ystart)*vol->X+(z-vol->Zstart)*vol->X*vol->Y;
	tar[index] = sou[index];
}


__global__ void maceOnGPU(float *v_data,float *w_data,float *z_data,Volume *vol,float GAMMA)
{
	int x = threadIdx.x+blockIdx.x*blockDim.x +vol->Xstart;
	int y = threadIdx.y+blockIdx.y*blockDim.y +vol->Ystart;
	int z = threadIdx.z+blockIdx.z*blockDim.z +vol->Zstart;
	//printf("%d %d\n ",y,z);
	if(x>=vol->Xend || y>=vol->Yend ||z>=vol->Zend) return;
	int i = (x-vol->Xstart)+(y-vol->Ystart)*vol->X+(z-vol->Zstart)*vol->X*vol->Y;
	w_data[i] = GAMMA*(2*v_data[i]-z_data[i]) + (1-GAMMA)*w_data[i];
}

__global__ void initial_zdata(float *vol_real,float *w_data,float *z_data,Volume *vol)
{
	int x = threadIdx.x+blockIdx.x*blockDim.x +vol->Xstart;
	int y = threadIdx.y+blockIdx.y*blockDim.y +vol->Ystart;
	int z = threadIdx.z+blockIdx.z*blockDim.z +vol->Zstart;
	//printf("%d %d\n ",y,z);
	if(x>=vol->Xend || y>=vol->Yend ||z>=vol->Zend) return;
	int i = (x-vol->Xstart)+(y-vol->Ystart)*vol->X+(z-vol->Zstart)*vol->X*vol->Y;
	z_data[i] = 2*vol_real[i] - w_data[i];
}

