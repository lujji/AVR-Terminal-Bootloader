#----------------------------------------------------------------------------
# On command line:
#
# make all = Make software.
#
# make clean = Clean out built project files.
#
# make coff = Convert ELF to AVR COFF.
#
# make extcoff = Convert ELF to AVR Extended COFF.
#
# make program = Download the hex file to the device, using avrdude.
#                Please customize the avrdude settings below first!
#
# make debug = Start either simulavr or avarice as specified for debugging,
#              with avr-gdb or avr-insight as the front end for debugging.
#
# make filename.s = Just compile filename.c into the assembler code only.
#
# make filename.i = Create a preprocessed source file for use in submitting
#                   bug reports to the GCC project.
#
# To rebuild project do "make clean" then "make all".
#----------------------------------------------------------------------------

# MCU name
MCU = atmega328p
# Code-assistance
CODE_ASSIST  = __AVR_ATmega328__

# Bootloader address (512 words)
#BOOT_ADDRESS = 0x7800
BOOT_ADDRESS = 0x7C00
LFUSE        = 0xff
HFUSE        = 0xdc

# Processor frequency.
#     Typical values are:
#         F_CPU =  1000000
#         F_CPU =  1843200
#         F_CPU =  2000000
#         F_CPU =  3686400
#         F_CPU =  4000000
#         F_CPU =  7372800
#         F_CPU =  8000000
#         F_CPU = 11059200
#         F_CPU = 14745600
#         F_CPU = 16000000
#         F_CPU = 18432000
#         F_CPU = 20000000
F_CPU = 14745600

TARGET = main

FORMAT = ihex
DEBUG = dwarf-2
DISTDIR =./dist
OBJDIR = $(DISTDIR)

SRC = $(wildcard *.c)

OPT = s

CSTANDARD = -std=gnu11

# Place -D or -U options here for C sources
CDEFS = -DF_CPU=$(F_CPU)UL -D$(CODE_ASSIST)

#---------------- Compiler Options C ----------------
#  -g*:          generate debugging information
#  -O*:          optimization level
#  -f...:        tuning, see GCC manual and avr-libc documentation
#  -Wall...:     warning level
#  -Wa,...:      tell GCC to pass this to the assembler.
#    -adhlns...: create assembler listing
CFLAGS = -g$(DEBUG)
CFLAGS += $(CDEFS)
CFLAGS += -O$(OPT)
CFLAGS += -Wall -Wno-main
CFLAGS += -fwhole-program -fno-move-loop-invariants
CFLAGS += -funsigned-char -funsigned-bitfields -fpack-struct -fshort-enums
CFLAGS += -fno-tree-scev-cprop
CFLAGS += -Wa,-adhlns=$(<:%.c=$(OBJDIR)/%.lst)
CFLAGS += $(CSTANDARD)

#---------------- Linker Options ----------------
#  -Wl,...:     tell GCC to pass this to linker.
#    -Map:      create map file
#    --cref:    add cross reference to  map file
LDFLAGS = -Wl,--section-start=.text=$(BOOT_ADDRESS),-Map=$(DISTDIR)/$(TARGET).map,--cref,--relax

#---------------- Programming Options (avrdude) ----------------
avrdude =
AVRDUDE_PROGRAMMER = avrisp2
AVRDUDE_PORT = usb
AVRDUDE_WRITE_FLASH = -U flash:w:$(DISTDIR)/$(TARGET).hex
AVRDUDE_WRITE_FUSES = -U lfuse:w:$(LFUSE):m -U hfuse:w:$(HFUSE):m

AVRDUDE_FLAGS = -p $(MCU) -P $(AVRDUDE_PORT) -c $(AVRDUDE_PROGRAMMER)
AVRDUDE_FLAGS += $(AVRDUDE_NO_VERIFY)
AVRDUDE_FLAGS += $(AVRDUDE_VERBOSE)
AVRDUDE_FLAGS += $(AVRDUDE_ERASE_COUNTER)
AVRDUDE_FLAGS += -B 2MHz

#============================================================================

# Define programs and commands.
SHELL = sh
CC = avr-gcc
OBJCOPY = avr-objcopy
OBJDUMP = avr-objdump
SIZE = avr-size
AR = avr-ar rcs
NM = avr-nm
AVRDUDE = avrdude
REMOVE = rm -f
REMOVEDIR = rm -rf
COPY = cp
WINSHELL = cmd

# Messages
MSG_SIZE_BEFORE = Size before:
MSG_SIZE_AFTER = Size after:
MSG_FLASH = Creating load file for Flash:
MSG_EEPROM = Creating load file for EEPROM:
MSG_EXTENDED_LISTING = Creating Extended Listing:
MSG_SYMBOL_TABLE = Creating Symbol Table:
MSG_LINKING = Linking:
MSG_COMPILING = Compiling C:
MSG_CLEANING = Cleaning project:

# object files
OBJ = $(SRC:%.c=$(OBJDIR)/%.o)

# listing files
LST = $(SRC:%.c=$(OBJDIR)/%.lst)

# Compiler flags to generate dependency files.
GENDEPFLAGS = -MMD -MP -MF .dep/$(@F).d

ALL_CFLAGS = -mmcu=$(MCU) -I. $(CFLAGS) $(GENDEPFLAGS)

# Default target.
all: begin gccversion sizebefore build sizeafter end

# Change the build target to build a HEX file or a library.
build: elf hex eep lss sym

elf: $(DISTDIR)/$(TARGET).elf
hex: $(DISTDIR)/$(TARGET).hex
eep: $(DISTDIR)/$(TARGET).eep
lss: $(DISTDIR)/$(TARGET).lss
sym: $(DISTDIR)/$(TARGET).sym

# Display size of file.
HEXSIZE = $(SIZE) --target=$(FORMAT) $(DISTDIR)/$(TARGET).hex
ELFSIZE = $(SIZE) $(DISTDIR)/$(TARGET).elf

sizebefore:
	@if test -f $(DISTDIR)/$(TARGET).elf; then echo; echo $(MSG_SIZE_BEFORE); $(ELFSIZE); \
	2>/dev/null; echo; fi

sizeafter:
	@if test -f $(DISTDIR)/$(TARGET).elf; then echo; echo $(MSG_SIZE_AFTER); $(ELFSIZE); \
	2>/dev/null; echo; fi

gccversion :
	@$(CC) --version

# Program the device.
program: $(DISTDIR)/$(TARGET).hex $(DISTDIR)/$(TARGET).eep
	$(AVRDUDE) $(AVRDUDE_FLAGS) $(AVRDUDE_WRITE_FLASH) $(AVRDUDE_WRITE_EEPROM)

# Program fuses.
program-fuses:
	$(AVRDUDE) $(AVRDUDE_FLAGS) $(AVRDUDE_WRITE_FUSES)

dump:
	$(AVRDUDE) $(AVRDUDE_FLAGS) -U flash:r:dump.hex:i

# Create final output files (.hex, .eep) from ELF output file.
%.hex: %.elf
	@echo
	@echo $(MSG_FLASH) $@
	$(OBJCOPY) -O $(FORMAT) -R .eeprom -R .fuse -R .lock $< $@

%.eep: %.elf
	@echo
	@echo $(MSG_EEPROM) $@
	-$(OBJCOPY) -j .eeprom --set-section-flags=.eeprom="alloc,load" \
	--change-section-lma .eeprom=0 --no-change-warnings -O $(FORMAT) $< $@ || exit 0

# Create extended listing file from ELF output file.
%.lss: %.elf
	@echo
	@echo $(MSG_EXTENDED_LISTING) $@
	$(OBJDUMP) -h -S -z $< > $@

# Create a symbol table from ELF output file.
%.sym: %.elf
	@echo
	@echo $(MSG_SYMBOL_TABLE) $@
	$(NM) -n $< > $@

# Link: create ELF output file from object files.
.SECONDARY : $(DISTDIR)/$(TARGET).elf
.PRECIOUS : $(OBJ)
%.elf: $(OBJ)
	@echo
	@echo $(MSG_LINKING) $@
	$(CC) $(ALL_CFLAGS) $^ --output $@ $(LDFLAGS)

# Compile: create object files from C source files.
$(OBJDIR)/%.o : %.c
	@echo
	@echo $(MSG_COMPILING) $<
	$(CC) -c $(ALL_CFLAGS) $< -o $@

# Compile: create assembler files from C source files.
%.s : %.c
	$(CC) -S $(ALL_CFLAGS) $< -o $@

# Create preprocessed source for use in sending a bug report.
%.i : %.c
	$(CC) -E -mmcu=$(MCU) -I. $(CFLAGS) $< -o $@


# Target: clean project.
clean: begin clean_list end

clean_list :
	@echo
	@echo $(MSG_CLEANING)
	$(REMOVE) $(DISTDIR)/$(TARGET).hex
	$(REMOVE) $(DISTDIR)/$(TARGET).eep
	$(REMOVE) $(DISTDIR)/$(TARGET).cof
	$(REMOVE) $(DISTDIR)/$(TARGET).elf
	$(REMOVE) $(DISTDIR)/$(TARGET).map
	$(REMOVE) $(DISTDIR)/$(TARGET).sym
	$(REMOVE) $(DISTDIR)/$(TARGET).lss
	$(REMOVE) $(OBJDIR)/*.o
	$(REMOVE) $(OBJDIR)/*.lst
	$(REMOVE) $(SRC:.c=.s)
	$(REMOVE) $(SRC:.c=.d)
	$(REMOVE) $(SRC:.c=.i)
	$(REMOVEDIR) $(OBJDIR)
	$(REMOVEDIR) $(DISTDIR)
	$(REMOVEDIR) .dep

# Create object files directory
$(shell mkdir $(OBJDIR) 2>/dev/null)

# Create binary files directory
$(shell mkdir $(DISTDIR) 2>/dev/null)

# Include the dependency files.
-include $(shell mkdir .dep 2>/dev/null) $(wildcard .dep/*)

# Listing of phony targets.
.PHONY : all begin finish end sizebefore sizeafter gccversion \
build elf hex eep lss sym clean clean_list program
