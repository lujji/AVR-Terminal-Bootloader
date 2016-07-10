#include "config.h"
#include <avr/io.h>
#include <avr/wdt.h>
#include <avr/boot.h>
#include <avr/interrupt.h>
#include <util/setbaud.h>

#define out(x) {UART_putchar(x);}

static uint8_t buffer[RX_BUFFER_LEN];
static uint8_t *head;

static uint8_t data_buffer[SPM_PAGESIZE];
static uint8_t data_count = 0;

static uint16_t page = 0;
static uint8_t page_offset = 0;

static void UART_init() {
    UBRR0H = UBRRH_VALUE;
    UBRR0L = UBRRL_VALUE;
    UCSR0B = (1 << RXEN0) | (1 << TXEN0);
}

static void UART_putchar(uint8_t data) {
    while (!(UCSR0A & (1 << UDRE0)));
    UDR0 = data;
}

static uint8_t UART_getchar() {
    while (!(UCSR0A & (1 << RXC0)));
    return UDR0;
}

static inline void reboot() {
    /* Wait until watchdog reboots MCU */
    while (1);
}

/* hex char -> decimal  */
static uint8_t hex2dec(uint8_t x) {
    if (x < 'A')
        return (x - '0');
    else if (x < 'a')
        return (x - '7');
    else
        return (x - 'W');
}

/* 2 hex chars -> decimal */
static uint8_t hex2byte(uint8_t a, uint8_t b) {
    return (hex2dec(a) << 4)+hex2dec(b);
}

void write_flash_page() {
    boot_spm_busy_wait();
    boot_page_erase(page);
    boot_spm_busy_wait();
    boot_page_write(page);
}

/**
 * Push contents of data_buffer into temporary flash buffer.
 * Once the buffer is full, it's written into the flash page.
 */
void page_buffer_push() {
    for (uint8_t i = 0; i < data_count; i += 2) {
        if (page_offset >= SPM_PAGESIZE) {
            write_flash_page();
            page += SPM_PAGESIZE;
            page_offset = 0;
        }

        uint16_t *ptr = (uint16_t *) (&data_buffer[i]);
        boot_spm_busy_wait();
        boot_page_fill(page + page_offset, *ptr);

        page_offset += 2;
    }

    data_count = 0;
}

enum rsp_type {
    WRITE_FAIL, WRITE_OK, WRITE_COMPLETE
};

/**
 * Parse hex buffer
 * @return WRITE_FAIL - failed CRC check,
 *         WRITE_OK - packet is fine,
 *         WRITE_COMPLETE - finished writing to flash
 */
static uint8_t parse_buffer() {

    enum {
        ofs0 = 1, // beginning of the record (first char after semicolon)
        ofs = ofs0 + 8 // beginning of data section
    };

    uint8_t len = hex2byte(buffer[ofs0], buffer[ofs0 + 1]);
    uint8_t addrH = hex2byte(buffer[ofs0 + 2], buffer[ofs0 + 3]);
    uint8_t addrL = hex2byte(buffer[ofs0 + 4], buffer[ofs0 + 5]);
    uint8_t rec = hex2byte(buffer[ofs0 + 6], buffer[ofs0 + 7]);
    uint8_t crc = len + addrH + addrL + rec;

    uint8_t i = 0;
    for (i = ofs; i < len * 2 + ofs; i += 2) {
        uint8_t wrd = hex2byte(buffer[i], buffer[i + 1]);
        crc += wrd;
        data_buffer[data_count++] = wrd;
    }
    uint8_t rec_crc = hex2byte(buffer[i], buffer[i + 1]);
    crc = ~crc + 1;

    if (rec_crc != crc) {
        /* CRC error */
        out(RSP_CRC_ERROR);
        reboot();
    }

    if (rec == 0x00) {
        /* Data record */
        out(RSP_DATA_RECORD);
        page_buffer_push();
        data_count = 0;
        return WRITE_OK;
    } else if (rec == 0x01) {
        /* EOF */
        out(RSP_EOF_REACHED);
        if (page_offset != 0) {
            write_flash_page();
        }
        return WRITE_COMPLETE;
    } else {
        /* Not supported */
        data_count = 0;
        return WRITE_OK;
    }

    return WRITE_FAIL;
}

/**
 * Poll UART and fill RX buffer until newline character is encountered.
 */
void uart_poll() {
    char c = 0;
    while (c != '\n') {
        c = UART_getchar();

        if (c == ':') {
            head = buffer; //rewind
        } else if (c == '\r' || c == '\0') {
            continue;
        }

        if (head == &buffer[RX_BUFFER_LEN]) {
            /* buffer overflow */
            out(RSP_BUFER_OVERFLOW);
            reboot();
        }

        *(head++) = c;
    }

    head = buffer;
}

static void print_version() {
    out('B');
    out('O');
    out('O');
    out('T');
    out('L');
    out('D');
    out('R');
    out('v');
    out('1');
    out('.');
    out('0');
    out('\n');
}

void main(void) {
    /* Prevent writing to bootloader section */
    boot_lock_bits_set(1 << BLB11);

    JUMPER_DDR &= ~(1 << JUMPER_PIN);
    JUMPER_PORT |= (1 << JUMPER_PIN);

    if (bit_is_clear(JUMPER_SFR, JUMPER_PIN)) {
        wdt_enable(WDTO_4S);

        head = buffer;

        UART_init();
        print_version();
        UART_putchar(XON);

        enum rsp_type ok = WRITE_OK;
        while (ok != WRITE_COMPLETE) {
            uart_poll();

            UART_putchar(XOFF);
            ok = parse_buffer();
            UART_putchar(XON);

            wdt_reset();
        }

        out(RSP_WRITE_COMPLETE);

        boot_spm_busy_wait();
        boot_rww_enable();
    }

    asm volatile ("jmp 0000");
}
