
    org $2400

SDLSTL  = $0230
CHBAS   = $02f4

TRIG0   = $d010
TRIG1   = $d011

GRACTL  = $d01d

PADDL0  = $0270
PADDL1  = $0271
PADDL2  = $0272
PADDL3  = $0273

PORTA   = $d300

CONSOL  = $d01f

; -----------------------------------------------------------------------------

font
    ins "httfont.fnt"

; -----------------------------------------------------------------------------

main
    mwa #dlist SDLSTL
    mva #>font CHBAS

loop
    jsr read_pots

    lda mode
    bne do_mode2

    jsr mode1_read_sticks
    jsr convert_pots
    jmp continue

do_mode2
    jsr mode2_read_sticks

continue
    lda:cmp:req 20

    jsr unmark_all
    jsr show_sticks
    jsr show_pots

    lda consol
    eor #7
    cmp #2
    bne loop

    lda 20
    clc
    adc #25
wait2
    cmp 20
    bne wait2

    lda mode
    eor #1
    sta mode
    bne display_mode2

    mwa #mode1 modeline
    jmp loop

display_mode2
    mwa #mode2 modeline

; we have to detect whether there is a stick present, otherwise waiting
; on the clock edges can block (or need a watchdog timer)

    mva #0 stick0_present
    mva #0 stick1_present

; check if there are clock signals on TRIG0 and/or TRIG1

    lda TRIG0
    ldy #5
detect0
    and TRIG0
    sta $d40a
    dey
    bpl detect0
    eor #1
    sta stick0_present

    lda TRIG1
    ldy #5
detect1
    and TRIG1
    sta $d40a
    dey
    bpl detect1
    eor #1
    sta stick1_present

    jmp loop

; -----------------------------------------------------------------------------

dlist
    dta $70, $47, a(title)
    dta $70, $02, $70, $46
modeline
    dta a(mode1)
    dta $70, $46, a(status)
    dta $70, $06, $06, $06, $06, $70, $06, $70, $06, $06, $06, $06, $70
    dta $06, $06, $70, $06, $06, $41
    dta a(dlist)

title
    dta d'  SNES2JOY TESTER   '

    dta d"  Use keyboard SELECT to change mode.  "

mode1
    dta d' compatibility mode '
mode2
    dta d'   endless stream   '

status
    dta d' STICK0    STICK1   '* 

directions
    dta d' up        up       '
    dta d' down      down     '
    dta d' left      left     '
    dta d' right     right    '

fire
    dta d' fire      fire     '

buttons
    dta d' a         a        '
    dta d' b         b        '
    dta d' x         x        '
    dta d' y         y        '

    dta d' start     start    '
    dta d' select    select   '

pots
    dta d' POTA 228  POTA 228 '
    dta d' POTB 228  POTB 228 '

; -----------------------------------------------------------------------------

    .struct stick
        up, down, left, right, fire .byte
        a, b, x, y, start, select   .byte
        pota, potb                  .byte
    .ends

stick0  stick
stick1  stick

mode    dta 0

; -----------------------------------------------------------------------------

unmark_all
    ldy #109
unmark
    lda directions,y
    and #$7f
    sta directions,y
    lda directions+110,y
    and #$7f
    sta directions+110,y
    dey:bpl unmark
    rts

; -----------------------------------------------------------------------------

showone .macro which, where
    lda :which
    beq already_unmarked
    lda #$80
zero
    tax:ldy #9
mark
    txa:ora:sta :where,y
    dey:bpl mark
already_unmarked
    .endm

show_sticks
    showone stick0.up     directions
    showone stick0.down   directions+20
    showone stick0.left   directions+40
    showone stick0.right  directions+60
    showone stick0.fire   directions+80
    showone stick0.a      directions+100
    showone stick0.b      directions+120
    showone stick0.x      directions+140
    showone stick0.y      directions+160
    showone stick0.start  directions+180
    showone stick0.select directions+200

    showone stick1.up     directions+10
    showone stick1.down   directions+30
    showone stick1.left   directions+50
    showone stick1.right  directions+70
    showone stick1.fire   directions+90
    showone stick1.a      directions+110
    showone stick1.b      directions+130
    showone stick1.x      directions+150
    showone stick1.y      directions+170
    showone stick1.start  directions+190
    showone stick1.select directions+210
    rts

; -----------------------------------------------------------------------------
;
; MODE 1 - Compatibility Mode

mode1_read_sticks
    lda TRIG0
    eor #1
    sta stick0.fire

    lda TRIG1
    eor #1
    sta stick1.fire

    lda PORTA
    eor #$ff
    tax

    and #1
    sta stick0.up
    txa
    and #2
    lsr
    sta stick0.down
    txa
    and #4
    :2 lsr
    sta stick0.left
    txa
    and #8
    :3 lsr
    sta stick0.right

    txa
    :4 lsr
    tax

    and #1
    sta stick1.up
    txa
    and #2
    lsr
    sta stick1.down
    txa
    and #4
    :2 lsr
    sta stick1.left
    txa
    and #8
    :3 lsr
    sta stick1.right
    rts

; -----------------------------------------------------------------------------

read_pots
    mva PADDL0 stick0.pota
    mva PADDL1 stick0.potb
    mva PADDL2 stick1.pota
    mva PADDL3 stick1.potb
    rts

bin
    dta 0
bcd
    dta 0, 0

bin2bcd
    sta bin
    sed
    lda #0
    sta bcd+0
    sta bcd+1

    ldx #8
conv
    asl bin
    lda bcd
    adc bcd
    sta bcd
    lda bcd+1
    adc bcd+1
    sta bcd+1
    dex
    bne conv
    cld
    rts

showpot .macro which, where
    lda :which
    jsr bin2bcd

    lda bcd+1
    clc
    adc #$10
    sta :where

    lda bcd
    lsr
    lsr
    lsr
    lsr
    clc
    adc #$10
    sta :where+1

    lda bcd
    and #$0f
    clc
    adc #$10
    sta :where+2
    .endm

show_pots
    showpot stick0.pota pots+6
    showpot stick0.potb pots+26
    showpot stick1.pota pots+16
    showpot stick1.potb pots+36
    rts

; -----------------------------------------------------------------------------

; Average readings:
;  Sel     Y+B  Y    B      None
;   1       39  58  115     228
;
; Buckets:
;   0....19     Select / Start
;   20...48     Y+B    / X+A
;   49...86     Y      / X
;   87..171     B      / A
;  172..228     None   / None

convert_pot .macro
    lda :1.:2
    cmp #172
    bcs stick_pot_done

    cmp #87
    bcc lt87

    stx :1.:3
    bne stick_pot_done

lt87
    cmp #49
    bcc lt49

    stx :1.:4
    bne stick_pot_done

lt49
    cmp #20
    bcc lt20

    stx :1.:3
    stx :1.:4
    bne stick_pot_done

lt20
    stx :1.:5

stick_pot_done
    .endm
 
convert_pots
    ldx #0
    stx stick0.a
    stx stick0.b
    stx stick0.x
    stx stick0.y
    stx stick0.start
    stx stick0.select
    stx stick1.a
    stx stick1.b
    stx stick1.x
    stx stick1.y
    stx stick1.start
    stx stick1.select
    inx

    convert_pot stick0 pota b y select
    convert_pot stick0 potb a x start
    convert_pot stick1 pota b y select
    convert_pot stick1 potb a x start

    rts

; -----------------------------------------------------------------------------
;
; MODE 2 - Endless Stream

stick0_present
    dta 0
stick1_present
    dta 0

stream0
    dta 0, 0
stream1
    dta 0, 0

mode2_read_stick .macro clock, mask, stream
    ldx :clock
wait_for_edge
    cpx :clock
    beq wait_for_edge

    ldx :clock
    lda PORTA
    and :mask
    sta :stream,x

wait_for_next_edge
    cpx :clock
    beq wait_for_next_edge

    ldx :clock
    lda PORTA
    and :mask
    sta :stream,x
    .endm

mode2_read_sticks
    lda #0
    sta stick0.fire
    sta stick1.fire

    lda #$0f
    sta stream0
    sta stream0+1
    lda #$f0
    sta stream1
    sta stream1+1

    lda stick0_present
    beq nostick0

    mode2_read_stick TRIG0 #$0f stream0

nostick0
    lda stick1_present
    beq nostick1

    mode2_read_stick TRIG1 #$f0 stream1

nostick1
    lda stream0
    ora stream1
    eor #$ff
    sta stream0
    lda stream0+1
    ora stream1+1
    eor #$ff
    sta stream0+1

    lda stream0+1
    tax

    and #1
    sta stick0.up
    txa
    and #2
    lsr
    sta stick0.down
    txa
    and #4
    :2 lsr
    sta stick0.left
    txa
    and #8
    :3 lsr
    sta stick0.right

    txa
    :4 lsr
    tax

    and #1
    sta stick1.up
    txa
    and #2
    lsr
    sta stick1.down
    txa
    and #4
    :2 lsr
    sta stick1.left
    txa
    and #8
    :3 lsr
    sta stick1.right

    lda stream0
    tax

    and #1
    sta stick0.b
    txa
    and #2
    lsr
    sta stick0.y
    txa
    and #4
    :2 lsr
    sta stick0.a
    txa
    and #8
    :3 lsr
    sta stick0.x

    txa
    :4 lsr
    tax

    and #1
    sta stick1.b
    txa
    and #2
    lsr
    sta stick1.y
    txa
    and #4
    :2 lsr
    sta stick1.a
    txa
    and #8
    :3 lsr
    sta stick1.x

    ldx #0
    ldy #1

    stx stick0.select
    lda PADDL0
    bmi nosel0
    sty stick0.select

nosel0
    stx stick0.start
    lda PADDL1
    bmi nosta0
    sty stick0.start

nosta0
    stx stick1.select
    lda PADDL2
    bmi nosel1
    sty stick1.select

nosel1
    stx stick1.start
    lda paddl3
    bmi nosta1
    sty stick1.start

nosta1
    rts

; -----------------------------------------------------------------------------

    org $02e0

    dta a(main)

