CURR_DIR = $(shell pwd)
SOURCES = $(wildcard $(CURR_DIR)/src/*)
BUILDDIR = $(subst /src/,/build/,$(SOURCES))
PROGS = $(subst $(CURR_DIR)/src/,,$(SOURCES))
CLEAN_PROGS = $(subst $(CURR_DIR)/src/,clean-,$(SOURCES))


CTYPE = gcc

.PHONY: all dir compile $(SOURCES)

all: dir compile

intel: CTYPE = intel
intel: dir compile

inteltogether: CTYPE = inteltogether
inteltogether: dir compile


dir:
	@echo Setting up directories
	@mkdir -p $(BUILDDIR)
	@mkdir -p dist
	

compile: $(SOURCES)

$(SOURCES): $(CURR_DIR)/src/% : $(CURR_DIR)/src/%/makefile
	@cd $@ && make $(CTYPE) SOURCEDIR=$@ BUILDDIR=$(CURR_DIR)/build/$* EXECUTABLE=$(CURR_DIR)/dist/$*
	@echo

clean:
	rm -rf $(BUILDDIR)
	rm -rf dist/*

$(PROGS): % : $(CURR_DIR)/src/%/makefile
	@mkdir -p $(CURR_DIR)/build/$@
	@cd $(CURR_DIR)/src/$@ && make $(CTYPE) SOURCEDIR=$(CURR_DIR)/src/$@ BUILDDIR=$(CURR_DIR)/build/$@ EXECUTABLE=$(CURR_DIR)/dist/$@
	@echo

$(CLEAN_PROGS): clean-% : $(CURR_DIR)/src/%/makefile
	rm -rf build/$(subst clean-,,$@)
	rm -rf dist/$(subst clean-,,$@)
