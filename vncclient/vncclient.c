/*
 * Valence 64 - The input-only VNC client for the Commodore 64.
 *
 * Copyright 2012 David Simmons
 * http://cafbit.com/
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "contiki.h"
#include "contiki-net.h"
#include "dev/leds.h"
#include <stdio.h>
#include <string.h>
#include <peekpoke.h>

// defines
#define VNC_PORT 5900
#define VNC_SECURITY_TYPE_NONE 0x01
#define TIMEOUT 200
#define BUFFER_SIZE 640
// relevant c64 memory locations
#define C64_NDX     0x00C6
#define C64_KEYD    0x0277
#define C64_VICSCN  0x0400
#define C64_COLOR   0xD800
#define C64_GETIN   0xFFE4

// this is only used in the oddball case that there's no
// configuration file
const uint8_t default_vnc_server[] = { 192, 168, 1, 229 };

// general-purpose buffer
static uint8_t buffer[BUFFER_SIZE];

// states
typedef enum {
    VNC_STATE_HANDSHAKE = 0,
    VNC_STATE_INIT = 1,
    VNC_STATE_OPERATION = 2
} vnc_state_t;

// our context structure
typedef struct {
    uip_ipaddr_t addr;
    uint8_t connection_succeeded;
    unsigned char idle;
    struct psock psock;
    struct psock inbound;
    struct psock outbound;
    vnc_state_t state;
    uint8_t num_sec_types;
    uint16_t n;
    uint16_t width;
    uint16_t height;
    uint16_t x, y;
    uint16_t server_name_length;
    uint8_t mouse_mode;
} vnc_context_t;
static vnc_context_t vnc_context_storage;

// contiki process setup
PROCESS(vncclient_process, "vncclient");
AUTOSTART_PROCESSES(&vncclient_process);

// PETSCII to screen-code translator
//#define S(c) ((c>=0x40 && c<0x60)?(c-0x40):((c<0x20 || c>=0x60)?0x00:c))

// screen layout
// (corresponds to the screen drawn by the BASIC code)
static const uint8_t status_row = 21;
static const uint8_t mode_row = 14;
static const uint8_t mode_mouse_col = 21;
static const uint8_t mode_mouse_len = 5;
static const uint8_t mode_keyboard_col = 27;
static const uint8_t mode_keyboard_len = 8;

//======================================================================
// utility functions
//======================================================================

// read three ASCII digits as an integer value
static int c3_to_int(const uint8_t *s) {
    if (((*s < 0x30) || (*s > 0x39)) ||
        (*(s+1) < 0x30) || (*(s+1) > 0x39) ||
        (*(s+2) < 0x30) || (*(s+2) > 0x39) ) {
        return 0;
    }
    return ((*s-0x30)*100) + (*(s+1)-0x30)*10 + (*(s+2)-0x30);
}

// update the status line
static void status(const char *msg) {
    const char *m;
    char *s = (char *)(C64_VICSCN + (status_row*40)+1);
    memset(s, 0x20, 38);
    memset((char *)(C64_COLOR + (status_row*40)+1), 0x07, 38);
    s += 19-strlen(msg)/2;
    for (m=msg; *m!='\0'; m++) {
        char c = *m;
        if (c>=0x40 && c<0x60) {
            c -= 0x40;
        } else if (c<0x20 || c>=0x60) {
            c = 0x20;
        }
        *(s++) = c;
    }
}

// update the mouse/keyboard indicator
static void show_mode(uint8_t mouse_mode) {
    static char *p;
    int i;
    p = (char *)(C64_VICSCN + mode_row*40 + mode_mouse_col);
    for (i=0; i<mode_mouse_len; i++, p++) {
        if (mouse_mode) {
            *p = *p | 0x80;
        } else {
            *p = *p & 0x7F;
        }
    }
    p = (char *)(C64_VICSCN + mode_row*40 + mode_keyboard_col);
    for (i=0; i<mode_keyboard_len; i++, p++) {
        if (mouse_mode) {
            *p = *p & 0x7F;
        } else {
            *p = *p | 0x80;
        }
    }
}

//======================================================================
// network infrastructure
//======================================================================

// perform VNC/RFB handshaking
static int do_handshake(vnc_context_t *vnc) {
    uint8_t i, v1, v2, found;
    const static uint8_t client_version[] = 
        { 0x52, 0x46, 0x42, 0x20,
          0x30, 0x30, 0x33, 0x2E,
          0x30, 0x30, 0x38, 0x0A }; // "RFB 003.008\n"

    //------------------------------------------------------------
    // version handshake
    //------------------------------------------------------------

    PSOCK_BEGIN(&vnc->psock);
    PSOCK_INIT(&vnc->psock, buffer, 12);

    // read server version
    PSOCK_READBUF(&vnc->psock);
    // parse server version
    if (
        (buffer[0] != 0x52) ||
        (buffer[1] != 0x46) ||
        (buffer[2] != 0x42) ||
        (buffer[3] != 0x20) ||
        (buffer[7] != 0x2E) ||
        (buffer[11] != 0x0A)
    ) {
        status("bad version string");
        PSOCK_CLOSE(&vnc->outbound);
        PSOCK_EXIT(&vnc->outbound);
    }
    v1 = c3_to_int(buffer+4);
    v2 = c3_to_int(buffer+8);
    if ((v1<3)||(v2<8)) {
        //printf("unsupported server version: %d.%d\n",v1,v2);
        status("unsupported server version");
        PSOCK_CLOSE(&vnc->outbound);
        PSOCK_EXIT(&vnc->outbound);
    }
    //printf("version detected: %d.%d\n", v1,v2);

    // send our version (3.8)
    PSOCK_SEND(&vnc->psock, client_version, sizeof(client_version));

    //------------------------------------------------------------
    // security handshake
    //------------------------------------------------------------

    // receive the list of supported authentication methods
    // from the server.
    PSOCK_INIT(&vnc->psock, buffer, 1);
    PSOCK_READBUF(&vnc->psock);
    vnc->num_sec_types = buffer[0];
    if (vnc->num_sec_types == 0) {
        status("vnc handshake failure");
        PSOCK_CLOSE(&vnc->outbound);
        PSOCK_EXIT(&vnc->outbound);
    }
    PSOCK_INIT(&vnc->psock, buffer, vnc->num_sec_types);
    PSOCK_READBUF(&vnc->psock);
    found = 0;
    for (i=0; i<vnc->num_sec_types; i++) {
        if (buffer[i] == VNC_SECURITY_TYPE_NONE) {
            found = 1;
            break;
        }
    }
    if (! found) {
        status("server does not support security-none");
        PSOCK_CLOSE(&vnc->outbound);
        PSOCK_EXIT(&vnc->outbound);
    }

    // tell the server we will use VNC_SECURITY_TYPE_NONE.
    buffer[0] = VNC_SECURITY_TYPE_NONE;
    PSOCK_SEND(&vnc->psock, buffer, 1);

    // read the security-result
    PSOCK_INIT(&vnc->psock, buffer, 4);
    PSOCK_READBUF(&vnc->psock);
    if (*((uint32_t*)buffer) != 0x00) {
        status("security failure");
        PSOCK_CLOSE(&vnc->outbound);
        PSOCK_EXIT(&vnc->outbound);
    }

    // transition to normal operation
    vnc->state = VNC_STATE_INIT;

    PSOCK_END(&vnc->psock);
}

// perform VNC/RFB initialization
static int do_init(vnc_context_t *vnc) {
    PSOCK_BEGIN(&vnc->psock);
    PSOCK_INIT(&vnc->psock, buffer, 24);
    //------------------------------------------------------------
    // client/server init
    //------------------------------------------------------------

    // client init
    // send shared-flag = 1 (allow other clients to connect)
    buffer[0] = 0x01;
    PSOCK_SEND(&vnc->psock, buffer, 1);

    // server init
    PSOCK_READBUF(&vnc->psock);
    vnc->width = buffer[0]<<8 | buffer[1];
    vnc->height = buffer[2]<<8 | buffer[3];
    vnc->server_name_length = buffer[22]<<8 | buffer[23];
    if (buffer[20] || buffer[21] || vnc->server_name_length > (BUFFER_SIZE-1)) {
        status("unsupported servername length");
        PSOCK_CLOSE(&vnc->outbound);
        PSOCK_EXIT(&vnc->outbound);
    }

    vnc->x = vnc->width/2;
    vnc->y = vnc->height/2;

    //PSOCK_INIT(&vnc->psock, buffer, vnc->server_name_length);
    PSOCK_INIT(&vnc->psock, buffer, 14);
    PSOCK_READBUF(&vnc->psock);
    buffer[vnc->server_name_length] = 0;
    //printf("server name: \"%s\"\n", buffer);

    // transition to normal operation
    vnc->state = VNC_STATE_OPERATION;

    PSOCK_END(&vnc->psock);
}

// add a keypress event to the outgoing VNC/RFB stream
static void add_key_event(vnc_context_t *vnc, uint8_t **buf_ptr, uint8_t c) {
    uint16_t keysym = 0;
    uint8_t *buf;

    // translate PETSCII to keysyms
    switch (c) {
    case 0x0D: // return
        keysym = 0x0D;
        break;
    case 0x14: // map delete to backspace
        keysym = 0xFF08;
        break;
    case 0x91: // up
        keysym = 0xFF52;
        break;
    case 0x9D: // left
        keysym = 0xFF51;
        break;
    case 0x11: // down
        keysym = 0xFF54;
        break;
    case 0x1D: // right
        keysym = 0xFF53;
        break;
    default:
        if (c>=0x20 && c<= 0x60) {
            if (c>=0x41 && c<=0x5A) {
                keysym = c + 0x20;
            } else {
                keysym = c;
            }
        }
    }
    if (keysym == 0) {
        return;
    }

    buf = *buf_ptr;
    buf[0] = 4;
    buf[1] = 1;
    buf[2] = 0;
    buf[3] = 0;
    buf[4] = 0; //(keysym >> 24);
    buf[5] = 0; //(keysym >> 16) & 0xFF;
    buf[6] = (keysym >> 8) & 0xFF;
    buf[7] = keysym & 0xFF;
    *buf_ptr = buf+8;
    buf = *buf_ptr;
    buf[0] = 4;
    buf[1] = 0;
    buf[2] = 0;
    buf[3] = 0;
    buf[4] = 0; //(keysym >> 24);
    buf[5] = 0; //(keysym >> 16) & 0xFF;
    buf[6] = (keysym >> 8) & 0xFF;
    buf[7] = keysym & 0xFF;
    *buf_ptr = buf+8;
}

// add a mouse movement event to the outgoing VNC/RFB stream
static void add_mouse_event(vnc_context_t *vnc, uint8_t **buf_ptr) {
    uint8_t *buf = *buf_ptr;
    buf[0] = 5;
    buf[1] = 0;
    buf[2] = vnc->x >> 8;
    buf[3] = vnc->x & 0xFF;
    buf[4] = vnc->y >> 8;
    buf[5] = vnc->y & 0xFF;
    *buf_ptr = buf+6;
}

// add a mouse button event to the outgoing VNC/RFB stream
static void add_mouse_button_event(vnc_context_t *vnc, uint8_t **buf_ptr, int button_mask) {
    uint8_t *buf = *buf_ptr;
    buf[0] = 5;
    buf[1] = button_mask;
    buf[2] = vnc->x >> 8;
    buf[3] = vnc->x & 0xFF;
    buf[4] = vnc->y >> 8;
    buf[5] = vnc->y & 0xFF;
    buf[6] = 5;
    buf[7] = 0x00;
    buf[8] = vnc->x >> 8;
    buf[9] = vnc->x & 0xFF;
    buf[10] = vnc->y >> 8;
    buf[11] = vnc->y & 0xFF;
    *buf_ptr = buf+12;
}

#define UNIT_MOVE 8

// process input events and generate the appropriate
// VNC/RFB events.
static int do_operation(vnc_context_t *vnc) {
    uint8_t *buf = uip_buf;
    uint8_t *end = uip_buf + UIP_APPDATA_SIZE;
    char key = 0;
    uint8_t joy;
    uint8_t joy_move_flag = 0;
    static uint8_t joy_fire_flag = 0; // track fire state

    // process joystick
    joy = PEEK(0xDC00);
    if (joy & 0x1F) {
        if (!(joy & (0x01<<0))) { // up
            vnc->y-=UNIT_MOVE; if (vnc->y <= 0) { vnc->y = 0; }
            joy_move_flag = 1;
        }
        if (!(joy & (0x01<<1))) { // down
            vnc->y+=UNIT_MOVE;
            if (vnc->y >= vnc->height) { vnc->y = vnc->height-1; }
            joy_move_flag = 1;
        }
        if (!(joy & (0x01<<2))) { // left
            vnc->x-=UNIT_MOVE;
            if (vnc->x <= 0) { vnc->x = 0; }
            joy_move_flag = 1;
        }
        if (!(joy & (0x01<<3))) { // right
            vnc->x+=UNIT_MOVE;
            if (vnc->x >= vnc->width) { vnc->x = vnc->width-1; }
            joy_move_flag = 1;
        }
        if (!(joy & (0x01<<4))) { // fire
            // if the joystick fire was previously noticed,
            // don't fire again until the fire switch is
            // seen open.  this is to prevent a "rapid fire"
            // effect which, while fun in games, is annoying
            // when navigating GUIs.
            if (! joy_fire_flag) {
                add_mouse_button_event(vnc, &buf, 0x01);
                joy_fire_flag = 1;
            }
        } else {
            // clear fire flag if the fire button has been released
            joy_fire_flag = 0;
        }
        if (joy_move_flag) {
            add_mouse_event(vnc, &buf);
        }
    }

    // process keys
    while (PEEK(C64_NDX)) {
        key = PEEK(C64_KEYD);
        __asm__ ("jsr %w", C64_GETIN);
        //printf("key pressed: %02x\n", key);

        if (key == 0x88 /* F7 */) {
            vnc->mouse_mode = ! vnc->mouse_mode;
            show_mode(vnc->mouse_mode);
        } else if (vnc->mouse_mode) {
            switch (key) {
            case 0x91:  // crsr up
                vnc->y-=UNIT_MOVE; if (vnc->y <= 0) { vnc->y = 0; }
                add_mouse_event(vnc, &buf);
                break;
            case 0x11:  // crsr down
                vnc->y+=UNIT_MOVE;
                if (vnc->y >= vnc->height) { vnc->y = vnc->height-1; }
                add_mouse_event(vnc, &buf);
                break;
            case 0x9D:  // crsr left
                vnc->x-=UNIT_MOVE;
                if (vnc->x <= 0) { vnc->x = 0; }
                add_mouse_event(vnc, &buf);
                break;
            case 0x1D:  // crsr right
                vnc->x+=UNIT_MOVE;
                if (vnc->x >= vnc->width) { vnc->x = vnc->width-1; }
                add_mouse_event(vnc, &buf);
                break;
            case 0x0D:  // return
            case 0x85:  // F1
                add_mouse_button_event(vnc, &buf, 0x01);
                break;
            case 0x86:  // F3
                add_mouse_button_event(vnc, &buf, 0x02);
                break;
            case 0x87:  // F5
                add_mouse_button_event(vnc, &buf, 0x04);
                break;
            }
        } else {
            // key mode
            add_key_event(vnc, &buf, key);
        }
        if (end-buf < 12) {
            break;
        }
    }
    if (buf > uip_buf) {
        //uint8_t *s;
        //for (s=uip_buf; s<buf; s++) {
            //printf("%02x ", *s);
        //}
        //printf("\n");
        //printf("sending %d bytes\n", buf-uip_buf);
        uip_send(uip_buf, buf-uip_buf);
    }
}

//----------------------------------------------------------------------
// outbound protothread
//----------------------------------------------------------------------

static int handle_outbound(vnc_context_t *vnc) {
    PSOCK_BEGIN(&vnc->outbound);
    PSOCK_CLOSE(&vnc->outbound);
    PSOCK_EXIT(&vnc->outbound);
    PSOCK_END(&vnc->outbound);
}

//----------------------------------------------------------------------
// inbound protothread
//----------------------------------------------------------------------

static int handle_inbound(vnc_context_t *vnc) {
    PSOCK_BEGIN(&vnc->inbound);
    PSOCK_END(&vnc->inbound);
}

//----------------------------------------------------------------------
// connection dispatch routine
//----------------------------------------------------------------------

static void handle_connection(vnc_context_t *vnc) {
    switch (vnc->state) {
    case VNC_STATE_HANDSHAKE:
        do_handshake(vnc);
        break;
    case VNC_STATE_INIT:
        do_init(vnc);
        break;
    case VNC_STATE_OPERATION:
        do_operation(vnc);
        break;
    default:
        handle_inbound(vnc);
        handle_outbound(vnc);
        break;
    }
}

//----------------------------------------------------------------------
// process
//----------------------------------------------------------------------

PROCESS_THREAD(vncclient_process, ev, data)
{
    vnc_context_t *vnc = &vnc_context_storage;
    struct uip_conn *conn;
    int loaded;

    // begun, this 8-bit process has.
    PROCESS_BEGIN();

    // initialize
    status("loading configuration...");
    memset(vnc, 0x00, sizeof(vnc_context_t));
    vnc->state = VNC_STATE_HANDSHAKE;
    vnc->mouse_mode = 1;
    show_mode(vnc->mouse_mode);

    // load the destination IP address from the configuration file
    loaded = 0;
    {
        uint8_t configured_vnc_server[4];
        int file = cfs_open("valence.cfg", CFS_READ);
        if (file>=0) {
            if (cfs_read(file, configured_vnc_server, sizeof(configured_vnc_server)) == sizeof(configured_vnc_server)) {
                uip_ipaddr(&vnc->addr,
                    configured_vnc_server[0],
                    configured_vnc_server[1],
                    configured_vnc_server[2],
                    configured_vnc_server[3]
                );
                loaded = 1;
            }
        }
    }
    if (loaded == 0) {
        uip_ipaddr(&vnc->addr,
            default_vnc_server[0],
            default_vnc_server[1],
            default_vnc_server[2],
            default_vnc_server[3]
        );
    }
    status("connecting...");

    // connect
    vnc->connection_succeeded = 0;
    conn = tcp_connect(&vnc->addr, UIP_HTONS(VNC_PORT), vnc);
    if (! conn) {
        status("error launching connect");
        PROCESS_EXIT();
    }

    // loop over TCP/IP events and dispatch them
    // to the protothreads.
    while (1) {
        PROCESS_WAIT_EVENT();

        if (ev == tcpip_event) {
            vnc_context_t *vnc = &vnc_context_storage;

            if (uip_closed()) {
                status("connection closed");
                PROCESS_EXIT();
            } else if (uip_aborted()) {
                if (! vnc->connection_succeeded) {
                    // retry
                    status("retrying...");
                    conn = tcp_connect(&vnc->addr, UIP_HTONS(VNC_PORT), vnc);
                    if (! conn) {
                        status("error launching reconnect");
                        PROCESS_EXIT();
                    }
                } else {
                    status("connection aborted\n");
                    PROCESS_EXIT();
                }
            } else if (uip_timedout()) {
                status("connection timed out\n");
                PROCESS_EXIT();
            } else if (uip_connected()) {
                status("connected");
                vnc->connection_succeeded = 1;
                handle_connection(vnc);
                vnc->idle = 0;
            } else if (vnc != NULL) {
                // is a poll needed?
                if (uip_poll()) {
                    vnc->idle++;
                    // don't timeout (for now...)
                    /*
                    if (vnc->idle > TIMEOUT) {
                        printf("application layer timeout\n");
                        uip_abort();
                        PROCESS_EXIT();
                    }
                    */
                } else {
                    vnc->idle = 0;
                }
                handle_connection(vnc);
            } else {
                status("major damage.\n");
                uip_abort();
                PROCESS_EXIT();
            }
        }
    }

    status("finished.\n");
    PROCESS_END();
}

