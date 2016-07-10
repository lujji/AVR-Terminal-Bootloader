#ifndef CONFIG_H
#define CONFIG_H

#include <avr/io.h>

#define BAUD            230400
#define RX_BUFFER_LEN   128

/* Bootloader entry jumper */
#define JUMPER_PIN      PD6
#define JUMPER_DDR      DDRD
#define JUMPER_PORT     PORTD
#define JUMPER_SFR      PIND

enum {
    /* Control characters */
    XON = 0x11,
    XOFF = 0x13,
    /* Response characters */
    RSP_DATA_RECORD = '.',
    RSP_CRC_ERROR = 'F',
    RSP_BUFER_OVERFLOW = 'X',
    RSP_EOF_REACHED = 'O',
    RSP_WRITE_COMPLETE = 'K'
};

#endif /* CONFIG_H */
