## AVR Terminal Bootloader

A simple bootloader for ATmega series of microcontrollers (ATmega88/168/328), which does not require any custom application on the host side to update firmware.
You can use any terminal that supports software flow control (like minicom or cutecom) to upload the hex file.
Bootloader uses under 1K of flash (804 bytes compiled w/ gcc v5.3.0, avr-libc-2.0.0).

### Features:

*   no custom software required
*   fits in 512 words bootloader section
*   enters bootloader by pulling a pin low

### Usage

In order to upload a .hex file you need to connect `JUMPER_PIN` (PD6 by default) to  ground.
After entering the bootloader you have 4 seconds to start uploading the file from terminal.
Default configuration is `230400 @ 8-N-1`, flow control: software.
Response types:
`OK` - upload successful,
`.` - packet received,
`F` - CRC error,
`X` - buffer overrun.

### Build instructions
To build and flash the bootloader run `make`, `make program`, `make program-fuses`.

The default configuration targets ATmega328P. To use a different MCU some makefile parameters have to be adjusted.
Set `MCU` and `F_CPU` variables. BOOTRST fuse must be set and BOOTSZ fuses should be configured for 512-word boot flash section.
Set `BOOT_ADDRESS` as per datasheet. Keep in mind that datasheets usually provide boot address in **word size** and GCC expects this parameter in **byte size**.
Therefore, the word address from the datasheet has to be **multiplied by 2**.
For example, atmega328 datasheet specifies bootloader address for 512-word size as 0x3E00. In this case, _byte size_ = (word size) * 2 = 0x3E00 * 2 = 0x7C00.

### Limitations

*   No EEPROM support
*   Hex address is ignored. Bootloader assumes that hex file has sequential addressing starting from 0x0000 (which is what your toolchain would produce anyway)
*   Firmware consistency is not checked during boot

