    DEVICE ZXSPECTRUM48

    ORG #8000

rom_cls       EQU #0DAF
rom_print     EQU #203C
rom_print_int EQU #1A1B
rom_pause     EQU #1F3F
rom_pause_end EQU #1F4F

sysvar_frames_count EQU +62
sysvar_print_x_pos  EQU +74
sysvar_print_y_pos  EQU +75
sysvar_attr         EQU +83
sysvar_tmp_attr     EQU +85

char_comma EQU #06
char_at    EQU #16

frames_in_step EQU 10

color_buffer EQU #5800 ; Screen attributes
dir_buffer   EQU color_buffer | 32768

bright_flag EQU 64
flash_flag  EQU 128

empty_color EQU 0
snake_color EQU 6<<3
apple_color EQU 4<<3

status_bar_color    EQU 7<<3 | bright_flag
game_over_color     EQU 2<<3 | bright_flag | flash_flag
press_any_key_color EQU 7

    ASSERT snake_color > apple_color
    ASSERT status_bar_color > apple_color

start_x EQU 16
start_y EQU 12

left  EQU -1  ; %11111111
right EQU +1  ; %00000001
up    EQU -32 ; %11100000
down  EQU +32 ; %00100000

    MACRO LD_BC_A
        LD C, A
        ADD A, A
        SBC A, A
        LD B, A
    ENDM

    MACRO COLOR_ADDR_TO_DIR_ADDR ; Switching HL to dir_buffer
        SET 7, H ; HL |= 32768
    ENDM

    MACRO DIR_ADDR_TO_COLOR_ADDR ; Switching HL to color_buffer
        RES 7, H ; HL &= ~32768
    ENDM

start
    ; Setup stack and enable interrupts
    LD SP, start
    EI

    ; Clear screen
    XOR A ; A = empty_color = 0
    LD (IY + sysvar_attr), A
    CALL rom_cls
    ; DE = 0

    ; Setting up score
    EX DE, HL
    DEC HL
    EXX
    ; HL' = score = -1

    ; Blue border
    INC A ; A = +1
    OUT (#FE), A

setup_snake
    LD HL, color_buffer + start_x + 32*start_y
    LD (HL), snake_color
    DEC L
    LD (HL), snake_color

    COLOR_ADDR_TO_DIR_ADDR

    LD (HL), A ; A = +1 (right)
    PUSH HL
    INC L
    LD (HL), A
    ; HL = head, (SP) = tail, (HL) = direction

update_score
    EXX

    ; Draw status bar
    LD (IY + sysvar_tmp_attr), status_bar_color
    LD DE, text_status_bar
    LD BC, text_status_bar.size
    CALL rom_print

    ; Increment score and print it
    INC HL
    LD B, H
    LD C, L
    CALL rom_print_int

    ; Print record
    LD (IY + sysvar_print_x_pos), 24
    LD BC, 0
var_record EQU $-2
    CALL rom_print_int

    EXX

    ; Setting up some constants
    LD DE, 31 << 8 | apple_color

spawn_apple
    ; Generating random address in color buffer
    LD A, R
    LD C, A
    RLCA
    XOR (IY + sysvar_frames_count)
    RLCA
    RLCA
    LD B, A

    XOR C
    AND D ; D = 31
    XOR B
    LD C, A

    LD A, B
    AND 3
    JR Z, spawn_apple
    ADD A, HIGH color_buffer - 1
    LD B, A

    ; Test cell is empty
    LD A, (BC)
    OR A ; empty_color = 0
    JR NZ, spawn_apple

    ; Drop apple
    LD A, E ; E = apple_color
    LD (BC), A

game_loop

handle_input
    ; Reading interface II keys [67890]
    LD BC, frames_in_step << 8 | #FF
1
    HALT
    LD A, #EF
    IN A, (#FE) ; A = %XXX67890
    AND C
    LD C, A
    DJNZ 1B

    ; Choosing different axis (C = now moving vertically ? left : down)
    ; and shifting key mask (%XXX67890 -> %90XXX678) if now moving vertically
    BIT 0, (HL)
    LD C, down
    JR NZ, 1F
    LD C, left
    RRCA
    RRCA
1
    ; Testing bits 1 and 2
    AND 6
    JP PE, move_head ; Neither or both keys are pressed

    ; Inverting if righter key (7 or 9) is pressed (left->right or down->up)
    SUB A, 4
    JR NZ, 1F
    SUB A, C ; A = 0
    LD C, A
1
    ; Updating direction
    LD (HL), C

move_head
    ; Move head to the next cell
    LD A, (HL)
    LD_BC_A
    ADD HL, BC

    LD (HL), C ; Store current direction in the head

    ; Checking bottom border
    LD A, H
    CP HIGH dir_buffer + 3
    JR NC, game_over ; Address is out of buffer

    ; Checking horizontal borders
    LD A, C ; C = direction
    RRCA
    JR NC, grab_cell ; Moved vertically
    XOR L
    AND D ; D = 31
    JR Z, game_over ; Moved left and now at right border or vice versa

grab_cell
    DIR_ADDR_TO_COLOR_ADDR

    ; Testing cell at head positing
    LD A, E ; E = apple_color
    CP (HL)
    JR C, game_over ; Bitten self

    ; Painting head
    LD (HL), snake_color

    COLOR_ADDR_TO_DIR_ADDR

    JR Z, update_score ; Ate apple

move_tail
    EX (SP), HL ; Exchange head <-> tail

    ; Clear tail cell
    DIR_ADDR_TO_COLOR_ADDR
    LD (HL), empty_color
    COLOR_ADDR_TO_DIR_ADDR

    ; Move tail to the next cell
    LD A, (HL)
    LD_BC_A
    ADD HL, BC

    EX (SP), HL ; Exchange head <-> tail

    JR game_loop

game_over
    EXX
    ; HL = score

    ; Print "GAME OVER"
    LD (IY + sysvar_tmp_attr), game_over_color
    ; DE = text_game_over
    LD BC, text_game_over.size
    CALL rom_print

    ; Print "press any key"
    LD (IY + sysvar_tmp_attr), press_any_key_color
    LD DE, text_press_any_key
    LD BC, text_press_any_key.size
    CALL rom_print
    ; BC = #FFFF, CF = 0

    ; Updating record if needed
    EX DE, HL
    LD HL, (var_record)
    SBC HL, DE
    JR NC, wait_any_key
    LD (var_record), DE

wait_any_key
    CALL rom_pause_end
    CALL rom_pause ; BC = delay = #FFFF -> wait infinitely

    JP start

text_status_bar
    DB char_at, 0, 0
    DB "Score:", char_comma, "Record:", char_comma
    DB char_at, 0, 7
.size EQU $ - text_status_bar

text_game_over
    DB char_at, 11, 12
    DB "GAME OVER"
    DB char_at, 21, 10
.size EQU $ - text_game_over

text_press_any_key EQU #09B3
.size              EQU 13

    DISPLAY "Code size: ", /D, $ - start
    SAVETAP "mySnake.tap", CODE, "mySnake", start, $ - start, start
