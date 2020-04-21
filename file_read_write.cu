#include <stdio.h>
#include <sys/types.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <time.h>
#include <omp.h>

int read_head_data(Projection *prj,MrcHeader *in_head,char *in_addr)
{
	FILE *in_file;
	in_file = fopen(in_addr,"r");
	if(!in_file){
		printf("Can not open in_file\n");
		return false;	
	}
	mrc_read_head(in_file,in_head);
	fclose(in_file);
	//printf("%d %d %d\n",in_head->nx,in_head->ny,in_head->nz);
	prj->X = in_head->nx;
	prj->Y = in_head->ny;
	prj->AngN = in_head->nz;
	return true;	
}

int read_txbr_data(Volume *vol,double *x_coef,double *y_coef,char *angle_addr)
{
	FILE *angle_file;
	angle_file = fopen(angle_addr,"r");
	if(!angle_file){
		printf("Can not open angle_file\n");
		return false;	
	}
	read_coef(vol,x_coef, y_coef, angle_file);
	fclose(angle_file);
	return true;
}

int read_all_data(MrcHeader *in_head,float *prj_real,char *in_addr)
{	
	FILE *in_context=fopen(in_addr,"r");
	if(!in_context){
		printf("Can not open in_context\n");
		return false;	
	}
	mrc_read_all(in_context,in_head,prj_real);
	fclose(in_context);
	return true;
}

int update_head(float *vol_real,MrcHeader *head)
{
	long double sum=0,amin,amax,amean;
	int prj_size=head->nx*head->ny,i,j;
	printf("updating head(FLOAT)...\n");
	amax = amin = vol_real[0];
	for(j = 0;j<head->nz;j++)
	{
		amean = 0;
		//printf("%d :%f\n",j,vol_real[90499]);
		for(i = 0;i<prj_size;i++)
		{
			int tmp_index = i+j*prj_size;
			if(vol_real[tmp_index]>amax) amax = vol_real[tmp_index];
			if(vol_real[tmp_index]<amin) amin = vol_real[tmp_index];
			amean+=vol_real[tmp_index];
		}
		amean/=prj_size;
		sum += amean;
	}
	amean = sum/head->nz;
	head->amin=amin;
	head->amax=amax;
	head->amean=amean;
	printf("head->amin is %f, head->amax is %f, head->amean is %f\n",head->amin, head->amax, head->amean);
	return true;
}

void write_data(char *out_addr,MrcHeader *out_head,float *vol_real)
{
	clean_file(out_addr);
	FILE *out_file;
	out_file = fopen(out_addr,"r+");
	if(!out_file){
		printf("Can not open out_file!\n");
		return;	
	}
	mrc_write_head(out_file,out_head);

	//printf("siezof out_head %ld \n",sizeof(MrcHeader));
	mrc_write_all(out_file,out_head,vol_real);
	printf("%d %d %d 1\n",out_head->nx,out_head->ny,out_head->nz);
	
	//mrc_update_head(out_file);
	fclose(out_file);
	return;
}

int set_head(MrcHeader *out_head,Volume *vol)
{
	out_head->nx=vol->X;
	out_head->ny=vol->Y;
	out_head->nz=vol->Z;

	out_head->nxstart=vol->Xstart;
	out_head->nystart=vol->Ystart;
	out_head->nzstart=vol->Zstart;

	out_head->mx=vol->X;
	out_head->my=vol->Y;
	out_head->mz=vol->Z;
	return true;
}
