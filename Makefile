objects=main.o read_write_mrc.o
MAIN = main.cu
MAIN:$(objects)
	nvcc -arch=sm_35 -o MAIN $(objects)
main.o:$(MAIN) file_read_write.cu sirt.cu read_write_mrc.h atom.h
	nvcc -arch=sm_35 -c $(MAIN)
read_write_mrc.o:read_write_mrc.cpp read_write_mrc.h
	g++ -c read_write_mrc.cpp
.PHONY:clean
clean:
	rm MAIN $(objects)
