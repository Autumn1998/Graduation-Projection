#include "read_write_mrc.h"

int max(int a,int b)
{
	if(a>b) return a;
	return b;
}
int min(int a,int b)
{
	if (a>b) return b;
	return a;
}


long get_file_size(FILE *fin)
{
	fseek(fin,0,SEEK_END);
	return ftell(fin);
}

/*******************************************************************************************/
int mrc_init_head(MrcHeader *head)
{
  head->nx=0;
  head->ny=0;
  head->nz=0;

  head->mode=MRC_MODE_FLOAT;

  head->nxstart=0;
  head->nystart=0;
  head->nzstart=0;

  head->mx=1;
  head->my=1;
  head->mz=1;

  head->xlen=1;
  head->ylen=1;
  head->zlen=1;

  head->alpha=90;
  head->beta=90;
  head->gamma=90;

  head->mapc=1;
  head->mapr=2;
  head->maps=3;

  head->amin=0;
  head->amax=255;
  head->amean=128;

  head->ispg=0;
  head->nsymbt=0;

  head->next=0;

  head->creatid=1000;
  head->cmap[0]='M';
  head->cmap[1]='A';
  head->cmap[2]='P';

  head->stamp[0]='D';
  return 0;
}


/*******************************************************************************************/
int read_coef(Volume *vol, double *x_coef, double *y_coef, FILE *f_coef)
{
	char *line_buff = (char *)malloc(TEX_LINE_MAX);
	char *tmp;
	int i=0,j=0,ang_num=0;
	while(fgets(line_buff,TEX_LINE_MAX,f_coef)!=NULL)
	{
		if(line_buff[0] == 'l') ang_num++;
		else if(line_buff[0] == 'x' && line_buff[1] == '-' && line_buff[2] != '>')
		{
			tmp = strtok(line_buff," ");
			while(tmp!=NULL)
			{
				tmp = strtok(NULL," ");
				if(tmp!=NULL)
				{
					x_coef[i++]=strtod(tmp,NULL);
					//printf("x_coef[%d]:%lf\n",i-1,x_coef[i-1]);
				}
			}			
		}else if(line_buff[0] == 'y' && line_buff[1] == '-' && line_buff[2] != '>')
		{
			tmp = strtok(line_buff," ");
			while(tmp!=NULL)
			{
				tmp = strtok(NULL," ");
				if(tmp!=NULL)
				{
					y_coef[j++]=strtod(tmp,NULL);
					//printf("y_codf[%d]:%lf\n",j-1,y_coef[j-1]);
				}
			}			
		}else if(line_buff[0] == 'x' && line_buff[1] == '-' && line_buff[2] == '>')
		{
			line_buff[2] = ':';
			tmp = strtok(line_buff,":");
			tmp = strtok(NULL,":");;
			vol->Xstart = min(vol->Xstart,atoi(tmp) );
			tmp = strtok(NULL,":");
			tmp = strtok(NULL,":");
			vol->Xend = max(vol->Xend,atoi(tmp) );
		}else if(line_buff[0] == 'y' && line_buff[1] == '-' && line_buff[2] == '>')
		{
			line_buff[2] = ':';
			tmp = strtok(line_buff,":");
			tmp = strtok(NULL,":");
			vol->Ystart = min(vol->Ystart,atoi(tmp) );
			tmp = strtok(NULL,":");
			tmp = strtok(NULL,":");
			vol->Yend = max(vol->Yend,atoi(tmp) );
		
		}else if(line_buff[0] == 'z' && line_buff[1] == '-' && line_buff[2] == '>')
		{
			line_buff[2] = ':';
			tmp = strtok(line_buff,":");
			tmp = strtok(NULL,":");
			vol->Zstart = min(vol->Zstart,atoi(tmp) );
			tmp = strtok(NULL,":");
			tmp = strtok(NULL,":");
			vol->Zend = max(vol->Zend,atoi(tmp) );
		}
	}
	//printf("Angle_num:%d\n",ang_num);
	return 1;
}

int mrc_read_all(FILE *fin,MrcHeader *head,float *mrc_data_all)
{
	int headsize = get_file_size(fin) - (long long) head->nx * head->ny * head->nz * sizeof(short);
	//compute the offset	
//	printf("Headsize:%d  Length:%d\n",headsize,head->nx*head->ny*head->nz);

	unsigned char buf_byte;
	short buf_short;
	short buf_ushort;
	
	fseek(fin,headsize,SEEK_SET);
	
	switch(head->mode)
	{
		case MRC_MODE_BYTE:
			printf("MRC_MODE_TYPE = BYTE\n");
			for(long i=0;i<head->nx*head->ny*head->nz;i++)
			{
				fread(&buf_byte,sizeof(char),1,fin);
				mrc_data_all[i] = (float)buf_byte;
			}
			break;
		case MRC_MODE_SHORT:
			printf("MRC_MODE_TYPE = SHORT\n");
			for(long i=0;i<head->nx*head->ny*head->nz;i++)
			{
				fread(&buf_short,sizeof(short),1,fin);
				mrc_data_all[i] = (float)buf_short;
				/**				
				if(i<=1000)
				{
					printf("%f ",mrc_data_all[i]);
					if(i%10 == 0) printf("\n");
				}
				***/
			}
			break;
		case MRC_MODE_USHORT:
			printf("MRC_MODE_TYPE = USHORT\n");
			for(long i=0;i<head->nx*head->ny*head->nz;i++)
			{
				fread(&buf_ushort,sizeof(char),1,fin);
				mrc_data_all[i] = (float)buf_ushort;
			}
			break;
		case MRC_MODE_FLOAT:
			printf("MRC_MODE_TYPE = FLOAT\n");
			if(!(fread(&mrc_data_all,sizeof(float),head->nx*head->ny*head->nz,fin)))
				printf("Error with mrc_read_all! Read float data failed!");
			break;
		default:
			printf("Error with Function 'mrc_read_all'!File type unknown!");
			break;
	}
	return 0;
}

int mrc_write_all(FILE *fout,MrcHeader *head, float *mrc_data_all)
{
    MrcHeader *h=(MrcHeader *)malloc(sizeof(MrcHeader));
	mrc_read_head(fout,h);
	//printf("BEFOR_write_all =>Update head ->OUT File nx:%d  ny:%d  nz:%d\n",h->nx,h->ny,h->nz);
	//printf("cmap 0:%c  1:%c  2:%c\n",head->cmap[0],head->cmap[1],head->cmap[2]);

	fseek(fout, HEAD_SIZE, SEEK_SET );
	//printf("Write all:%d %d %d \n",head->nx,head->ny,head->nz);
    fwrite(mrc_data_all,sizeof(float),head->nx*head->ny*head->nz,fout);
	
	//printf("Write all finished!\n");
	return true;
}

int mrc_update_head(FILE *fout)
{
	MrcHeader *head=(MrcHeader *)malloc(sizeof(MrcHeader));
	mrc_read_head(fout,head);
	printf("Update head ->OUT File nx:%d  ny:%d  nz:%d\n",head->nx,head->ny,head->nz);
	//printf("cmap 0:%c  1:%c  2:%c\n",head->cmap[0],head->cmap[1],head->cmap[2]);
	if(!head || !(head->cmap[0]=='M'&&head->cmap[1]=='A'&&head->cmap[2]=='P'))
	{
		printf("Fatal error! The Out_file is not a vaild mrc file!\n");
		return false;
	}

	long double sum,amin,amax,amean;
	int prj_size=head->nx*head->ny;
	unsigned long i,j;
	unsigned char *p_uchar;
	float *p_float;
	short *p_short;

	fseek(fout,HEAD_SIZE,SEEK_SET);
	switch (head->mode)
	{
	case MRC_MODE_BYTE:
		p_uchar = (unsigned char *)malloc(prj_size*sizeof(unsigned char*));
		printf("updating head(BYTE)...\n");
		sum = 0;
		amax = amin = p_uchar[0];
		for(j = 0;j<head->nz;j++)
		{
			amean = 0;
			fread(p_uchar,sizeof(unsigned char),prj_size,fout);
			for(i = 0;i<prj_size;i++)
			{
				if(p_uchar[i]>amax) amax = p_uchar[i];
				if(p_uchar[i]<amin) amin = p_uchar[i];
				amean+=p_uchar[i];
			}
			amean/=prj_size;
			sum += amean;
		}
		amean = sum/head->nz;
		free(p_uchar);
		break;
	case MRC_MODE_SHORT:
		p_short = (short*)malloc(prj_size*sizeof(short*));
		printf("updating head(SHORT)...\n");
		sum = 0;
		amax = amin = p_short[0];
		for(j = 0;j<head->nz;j++)
		{
			amean = 0;
			fread(p_short,sizeof(short),prj_size,fout);
			for(i = 0;i<prj_size;i++)
			{
				if(p_short[i]>amax) amax = p_short[i];
				if(p_short[i]<amin) amin = p_short[i];
				amean+=p_short[i];
			}
			amean/=prj_size;
			sum += amean;
		}
		amean = sum/head->nz;
		free(p_short);
		break;
	case MRC_MODE_FLOAT:
		p_float = (float *)malloc(prj_size*sizeof(float*));
		printf("updating head(FLOAT)...\n");
		sum = 0;
		amax = amin = p_float[0];
		for(j = 0;j<head->nz;j++)
		{
			amean = 0;
			fread(p_float,sizeof(float),prj_size,fout);
			printf("%ld :%f\n",j,p_float[90499]);
			for(i = 0;i<prj_size;i++)
			{
				if(p_float[i]>amax) amax = p_float[i];
				if(p_float[i]<amin) amin = p_float[i];
				amean+=p_float[i];
			}
			amean/=prj_size;
			sum += amean;
		}
		amean = sum/head->nz;
		free(p_float);
		break;
	default:
		break;
	}
	head->amin=amin;
	head->amax=amax;
	head->amean=amean;
	printf("head->amin is %f, head->amax is %f, head->amean is %f\n",head->amin, head->amax, head->amean);

	mrc_write_head(fout, head);
	free(head);
	printf("updating finished!\n");
	return true;
}

int mrc_write_head(FILE *fout,MrcHeader *head)
{
	//printf("\nFile size before WRITEHEAD:%ld\n",get_file_size(fout));
	if(ftello64(fout)!=0)rewind(fout);
	//printf("To be written:%d %d %d \n",head->nx,head->ny,head->nz);
	fwrite(head,sizeof(char),HEAD_SIZE,fout);
	//printf("File size after WRITEHEAD:%ld\n\n",get_file_size(fout));
	//printf("Write head finished!\n");
	return true;
}

int mrc_read_head (FILE *fin,  MrcHeader *head)
{
  if(ftello64(fin)!=0)rewind(fin);
  fread(head,sizeof(char),HEAD_SIZE,fin);
  return true;
}

int clean_file(char *file_addr)
{
	FILE * file = fopen(file_addr,"w");
	fclose(file);
	return true;
}
