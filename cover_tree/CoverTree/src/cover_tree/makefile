CDIR = ../commons
IDIR = ../../libs
MKLROOT=/home/manzilz/opt/mkl

DEBUG = -g
#-DNDEBUG
#-g

INTEL_CC = icc
INTEL_CFLAGS = $(DEBUG) -I"$(CDIR)" -I"$(IDIR)" -I"${MKLROOT}"/include -O3 -march=corei7-avx -std=c++11 -inline-factor=500 -no-inline-max-size -no-inline-max-total-size -use-intel-optimized-headers -parallel -qopt-prefetch=4 -qopt-mem-layout-trans=2 -pthread -openmp -c
INTEL_LFLAGS = $(DEBUG) -I"$(CDIR)" -I"$(IDIR)" -I"${MKLROOT}"/include -O3 -march=corei7-avx -std=c++11 -inline-factor=500 -no-inline-max-size -no-inline-max-total-size -use-intel-optimized-headers -parallel -qopt-prefetch=4 -qopt-mem-layout-trans=2 -pthread -openmp -Wl,--start-group ${MKLROOT}/lib/intel64/libmkl_intel_lp64.a ${MKLROOT}/lib/intel64/libmkl_core.a ${MKLROOT}/lib/intel64/libmkl_intel_thread.a -Wl,--end-group -lpthread -lm -ldl
INTEL_TFLAGS = -I"$(CDIR)" -fast -DNDEBUG -std=c++14 -inline-factor=500 -no-inline-max-size -no-inline-max-total-size -use-intel-optimized-headers -parallel -qopt-prefetch=4 -qopt-mem-layout-trans=3 -pthread 

GNU_CC = g++
GNU_CFLAGS = $(DEBUG) -I"$(CDIR)" -I"$(IDIR)" -O3 -march=corei7 -ffloat-store -pthread -std=c++11 -fopenmp  -c
GNU_LFLAGS = $(DEBUG) -I"$(CDIR)" -I"$(IDIR)" -O3 -march=corei7 -ffloat-store -pthread -std=c++11 -fopenmp

CC = $(GNU_CC)
CFLAGS = $(GNU_CFLAGS)
LFLAGS = $(GNU_LFLAGS)

SOURCEDIR = .
BUILDDIR = ../../build
EXECUTABLE = ../../dist/cover_tree

SOURCES = $(wildcard $(SOURCEDIR)/*.cpp)
OBJECTS = $(patsubst $(SOURCEDIR)/%.cpp,$(BUILDDIR)/%.o,$(SOURCES))

COMMONS = $(wildcard $(SOURCEDIR)/../commons/*.cpp)
COBJECT = $(patsubst $(SOURCEDIR)/../commons/%.cpp,$(BUILDDIR)/%.o,$(COMMONS))

all: $(EXECUTABLE)

gcc: $(EXECUTABLE)

intel: CC=$(INTEL_CC)
intel: CFLAGS=$(INTEL_CFLAGS)
intel: LFLAGS=$(INTEL_LFLAGS)
intel: $(EXECUTABLE)
 
$(EXECUTABLE): $(COBJECT)  $(OBJECTS)
	$(CC) $(LFLAGS) $^ -o $@

$(OBJECTS): $(BUILDDIR)/%.o : $(SOURCEDIR)/%.cpp
	$(CC) $(CFLAGS) $< -o $@

$(COBJECT): $(BUILDDIR)/%.o : $(SOURCEDIR)/../commons/%.cpp
	$(CC) $(CFLAGS) $< -o $@

inteltogether:
	$(INTEL_CC) $(INTEL_TFLAGS) $(SOURCES) $(COMMONS) -o $(EXECUTABLE)

clean:
	rm -rf $(BUILDDIR)/*
	rm -rf $(EXECUTABLE)
