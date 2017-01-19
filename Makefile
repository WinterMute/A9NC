#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------

ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=<path to>devkitARM")
endif

TOPDIR ?= $(CURDIR)
include $(DEVKITARM)/3ds_rules

#---------------------------------------------------------------------------------
# TARGET is the name of the output
# BUILD is the directory where object files & intermediate files will be placed
# SOURCES is a list of directories containing source code
# DATA is a list of directories containing data files
# INCLUDES is a list of directories containing header files
#
# NO_SMDH: if set to anything, no SMDH file is generated.
# ROMFS is the directory which contains the RomFS, relative to the Makefile (Optional)
# APP_TITLE is the name of the app stored in the SMDH file (Optional)
# APP_DESCRIPTION is the description of the app stored in the SMDH file (Optional)
# APP_AUTHOR is the author of the app stored in the SMDH file (Optional)
# ICON is the filename of the icon (.png), relative to the project folder.
#   If not set, it attempts to use one of the following (in this order):
#     - <Project name>.png
#     - icon.png
#     - <libctru folder>/default_icon.png
#---------------------------------------------------------------------------------
TARGET   := A9NC
BUILD    := build
SOURCES  := source
DATA     := data
INCLUDES := include
ROMFS    :=

VERSION_STRING := `git describe --tags --abbrev=0`
APP_TITLE       := $(TARGET)
APP_DESCRIPTION := ARM9 companion tool to receive payloads over wifi.
APP_AUTHOR      := d0k3

ICON            := meta/icon.png
BNR_IMAGE       := meta/banner.png
BNR_AUDIO       := meta/audio.wav
LOGO			:=  meta/logo.bcma.lz
RSF_FILE        := meta/a9nc.rsf

#---------------------------------------------------------------------------------
# options for code generation
#---------------------------------------------------------------------------------
ARCH     := -march=armv6k -mtune=mpcore -mfloat-abi=hard -mtp=soft

CFLAGS   := -g -Wall -O3 -mword-relocations \
            -fomit-frame-pointer -ffunction-sections \
            $(ARCH) \
           -DVERSION_STRING="\"$(VERSION_STRING)\""

CFLAGS   +=  $(INCLUDE) -DARM11 -D_3DS

CXXFLAGS := $(CFLAGS) -fno-rtti -fno-exceptions -std=gnu++11

ASFLAGS  := -g $(ARCH)
LDFLAGS   = -specs=3dsx.specs -g $(ARCH) -Wl,-Map,$(TARGET).map

LIBS     := -lz -lctru -lm

#---------------------------------------------------------------------------------
# list of directories containing libraries, this must be the top level containing
# include and lib
#---------------------------------------------------------------------------------
LIBDIRS  := $(CTRULIB) $(PORTLIBS)


#---------------------------------------------------------------------------------
# no real need to edit anything past this point unless you need to add additional
# rules for different file extensions
#---------------------------------------------------------------------------------
ifneq ($(BUILD),$(notdir $(CURDIR)))
#---------------------------------------------------------------------------------

export OUTPUT  :=  $(CURDIR)/$(TARGET)
export TOPDIR  :=  $(CURDIR)

export VPATH   :=  $(foreach dir,$(SOURCES),$(CURDIR)/$(dir)) \
                   $(foreach dir,$(DATA),$(CURDIR)/$(dir))

export DEPSDIR :=  $(CURDIR)/$(BUILD)

CFILES   := $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.c)))
CPPFILES := $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.cpp)))
SFILES   := $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.s)))
BINFILES := $(foreach dir,$(DATA),$(notdir $(wildcard $(dir)/*.*)))

#---------------------------------------------------------------------------------
# use CXX for linking C++ projects, CC for standard C
#---------------------------------------------------------------------------------
ifeq ($(strip $(CPPFILES)),)
  export LD := $(CC)
else
  export LD := $(CXX)
endif
#---------------------------------------------------------------------------------

export OFILES   := $(addsuffix .o,$(BINFILES)) \
                   $(CPPFILES:.cpp=.o) \
                   $(CFILES:.c=.o) \
                   $(SFILES:.s=.o)

export INCLUDE  := $(foreach dir,$(INCLUDES),-I$(CURDIR)/$(dir)) \
                   $(foreach dir,$(LIBDIRS),-I$(dir)/include) \
                   -I$(CURDIR)/$(BUILD)

export LIBPATHS :=  $(foreach dir,$(LIBDIRS),-L$(dir)/lib)

ifeq ($(strip $(ICON)),)
  icons := $(wildcard *.png)
  ifneq (,$(findstring $(TARGET).png,$(icons)))
    export APP_ICON := $(TOPDIR)/$(TARGET).png
  else
    ifneq (,$(findstring icon.png,$(icons)))
      export APP_ICON := $(TOPDIR)/icon.png
    endif
  endif
else
  export APP_ICON := $(TOPDIR)/$(ICON)
endif

ifeq ($(strip $(NO_SMDH)),)
  export _3DSXFLAGS += --smdh=$(CURDIR)/$(TARGET).smdh
endif

ifneq ($(ROMFS),)
  export _3DSXFLAGS += --romfs=$(CURDIR)/$(ROMFS)
endif

.PHONY: $(BUILD) clean all

#---------------------------------------------------------------------------------
all: $(BUILD)
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile

3dsx: $(BUILD)
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile 3dsx

cia: $(BUILD)
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile cia

$(BUILD):
	@[ -d $@ ] || mkdir -p $@

#---------------------------------------------------------------------------------
clean:
	@echo clean ...
	@$(RM) -r $(BUILD) $(TARGET).3dsx $(OUTPUT).smdh $(TARGET).elf $(TARGET).cia output/


#---------------------------------------------------------------------------------
else

DEPENDS := $(OFILES:.o=.d)

#---------------------------------------------------------------------------------
# main targets
#---------------------------------------------------------------------------------
all: $(OUTPUT).cia $(OUTPUT).3dsx

3dsx: $(OUTPUT).3dsx

cia: $(OUTPUT).cia

ifeq ($(strip $(NO_SMDH)),)
.PHONY: all
all:            $(OUTPUT).3dsx $(OUTPUT).smdh
$(OUTPUT).smdh: $(TOPDIR)/Makefile $(TOPDIR)/Makefile
$(OUTPUT).3dsx: $(OUTPUT).smdh
endif

$(OUTPUT).3dsx: $(OUTPUT).elf
$(OUTPUT).elf:  $(OFILES)

$(OFILES): $(TOPDIR)/Makefile

$(OUTPUT).cia:  $(OUTPUT).elf $(OUTPUT).smdh $(TARGET).bnr $(TOPDIR)/$(RSF_FILE)
	@makerom -f cia -target t -exefslogo -o $@ \
		-elf $(OUTPUT).elf -rsf $(TOPDIR)/$(RSF_FILE) \
		-ver "$(VERSION_STRING)" \
		-banner $(TARGET).bnr \
		-icon $(OUTPUT).smdh \
		-logo $(TOPDIR)/$(LOGO)
	@echo "built ... $(notdir $@)"

$(TARGET).bnr:  $(TOPDIR)/$(BNR_IMAGE) $(TOPDIR)/$(BNR_AUDIO)
	@bannertool makebanner -o $@ -i $(TOPDIR)/$(BNR_IMAGE) -a $(TOPDIR)/$(BNR_AUDIO)
	@echo "built ... $@"

#---------------------------------------------------------------------------------
# you need a rule like this for each extension you use as binary data
#---------------------------------------------------------------------------------
%.bin.o: %.bin
#---------------------------------------------------------------------------------
	@echo $(notdir $<)
	@$(bin2o)

-include $(DEPENDS)

#---------------------------------------------------------------------------------------
endif
#---------------------------------------------------------------------------------------
