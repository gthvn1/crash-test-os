;; ============================================================================
;; bootloader.asm
;;
;; It will load the stage2 by reading the second sector on the first
;; disk.

%include "include/constants.asm"

    org BOOTLO_OFFSET ; The code is loaded at 0x7C00 by the bootloader
                      ; We need to set it otherwise when later in the code
                      ; we will refer to memory location the address will be
                      ; wrong. For example mov al, [outputChar] will not work.

;; MEMORY LAYOUT
;; https://wiki.osdev.org/Memory_Map_(x86)
;;
;; 0x0000_0000 - 0x0000_03FF | 1KB   | Real Mode IVT
;; 0x0000_0400 - 0x0000_04FF | 256B  | Bios Data Area (BDA)
;; 0x0000_0500 - 0x0000_7BFF | ~30KB | Conventional memory
;; 0x0000_7C00 - 0x0000_7DFF | 512B  | It is us, the bootloader
;; 0x0000_7E00 - 0x0007_FFFF | 480KB | Conventional Memory
;;
;; 0x0008_0000 - 0x0009_FFFF | 128KB | EBDA
;; 0x000A_0000 - 0x000B_FFFF | 128KB | Video display memory
;; 0x000C_0000 - 0x000C_7FFF | 32KB  | Video BIOS
;; 0x000C_8000 - 0x000E_FFFF | 160KB | BIOS Expansions
;; 0x000F_0000 - 0x000F_FFFF | 64KB  | Motherboard BIOS
;;
;; We will use the 64KB from 0x0001_0000 - 0x0001_FFFF:
;;   - File Table  : 0x0001_0000 - 0x0001_01FF (512B)
;;   - Stage2      : 0x0001_0200 - 0x0001_09FF (2KB)
;;   - Loaded Prog : 0x0002_0000 - 0x0002_01FF (512B)
;; We keep the file table and the stage2 on the same segments. Otherwise when
;; we will access file table data from stage2 we need to make far jump.

    ; Setup the stack under us
    mov bp, BOOTLO_OFFSET
    mov ax, BOOTLO_SEG
    mov ss, ax
    mov sp, bp

    ; Setup video mode
    mov ah, 0x0 ; Set BIOS service to "set video mode"
    mov al, 0x3 ; 80x25 16 color text
    int 0x10    ; BIOS interrupt for video services

    ; First we will File Table from sector 2 at 0x1000:0x0000
    ; DON'T use load_file to load the file table because load_file relies on
    ; the fileTable IN MEMORY to load things...
    mov bx, FTABLE_SEG
    mov es, bx            ; es <- 0x1000
    xor bx, bx            ; bx <- 0x0
                          ; Set [es:bx] to 0x0001:0x0000,

    mov cx, 0x00_02       ; Cylinder: 0, Sector: 2
    mov al, 0x1           ; Read one sector (512 bytes)
    call load_disk_sector ; Read the file table from disk

    ; Now we can load the stage2 from sector 3 at 0x1000:0x0200
    push stage2Name
    push STAGE2_SEG
    push STAGE2_OFFSET
    call load_file
    cmp ax, 0
    jne fatal_error

    ; before jumping to the stage2 we need to setup segments
    mov ax, STAGE2_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    jmp STAGE2_SEG:STAGE2_OFFSET ; far jump to stage2

    ; Should not be reached because we never returned from stage2 space...
fatal_error:
    cli
    hlt

%include "include/load_file.asm"
%include "include/load_disk_sector.asm"

stage2Name db "stage2", 0

    times 510-($-$$) db 0    ; padding with 0s
    dw 0xaa55        ; BIOS magic number
