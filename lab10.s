.section .text
# Globl directives for functions callable from C or other files
.globl fibonacci_recursive
.globl fatorial_recursive
.globl torre_de_hanoi
.globl puts
.globl gets
.globl atoi
.globl itoa
.globl exit

# Note: putstr_no_newline and putchar are internally used by torre_de_hanoi.
# Making them .globl is not strictly necessary if only called from within this file,
# but it doesn't hurt.
.globl putstr_no_newline
.globl putchar

#-------------------------------------------------------------------------------
# Recursive Fibonacci
# int fibonacci_recursive(int num); a0: num -> a0: fib(num)
#-------------------------------------------------------------------------------
fibonacci_recursive:
    addi sp, sp, -16     # Space for ra, s0 (current num), s1 (result of fib(n-1))
    sw ra, 12(sp)
    sw s0, 8(sp)
    sw s1, 4(sp)

    mv s0, a0            # s0 = num

    beqz s0, fib_return_0    # Base case: if num == 0, return 0
    li t0, 1
    beq s0, t0, fib_return_1 # Base case: if num == 1, return 1

    # Recursive step for n > 1: fib(n) = fib(n-1) + fib(n-2)
    addi a0, s0, -1      # Arg for fib(num - 1)
    call fibonacci_recursive # a0 = fib(num - 1)
    mv s1, a0            # Save fib(num - 1) in s1

    addi a0, s0, -2      # Arg for fib(num - 2)
    call fibonacci_recursive # a0 = fib(num - 2)
                             # s1 still holds fib(num - 1)
    add a0, s1, a0       # a0 = fib(num - 1) + fib(num - 2)
    j fib_epilogue

fib_return_0:
    li a0, 0
    j fib_epilogue

fib_return_1:
    li a0, 1
    # Fall through to fib_epilogue

fib_epilogue:
    lw s1, 4(sp)
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#-------------------------------------------------------------------------------
# Recursive Factorial
# int fatorial_recursive(int num); a0: num -> a0: fact(num)
#-------------------------------------------------------------------------------
fatorial_recursive:
    addi sp, sp, -16     # Space for ra, s0 (current num)
    sw ra, 12(sp)
    sw s0, 8(sp)

    mv s0, a0            # s0 = num

    beqz s0, fact_base_case # Base case: if num == 0, return 1

    # Recursive step: result = num * fact(num - 1) for num > 0
    addi a0, s0, -1      # a0 = num - 1
    call fatorial_recursive  # a0 = fact(num - 1)
    mul a0, s0, a0       # a0 = current_num * fact(num-1)
    j fact_epilogue

fact_base_case:          # This is for num == 0
    li a0, 1             # fact(0) = 1
    # Fall through to fact_epilogue

fact_epilogue:
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#-------------------------------------------------------------------------------
# Optimized Tower of Hanoi (Recursive)
# void torre_de_hanoi(int num_disks, char peg_from, char peg_aux, char peg_to)
# a0: num_disks, a1: from_peg, a2: aux_peg, a3: to_peg
#-------------------------------------------------------------------------------
torre_de_hanoi:
    addi sp, sp, -32    # Reduced stack frame: 32 bytes
    sw ra, 28(sp)       # Save ra
    sw s0, 24(sp)       # s0 for n (num_disks)
    sw s1, 20(sp)       # s1 for from_peg
    sw s2, 16(sp)       # s2 for aux_peg
    sw s3, 12(sp)       # s3 for to_peg
                        # 0(sp)-8(sp) unused by these saves, part of allocated frame

    mv s0, a0           # s0 = n (current num_disks for this call)
    mv s1, a1           # s1 = from_peg for this call
    mv s2, a2           # s2 = aux_peg for this call
    mv s3, a3           # s3 = to_peg for this call

    beqz s0, hanoi_epilogue # Base case: if n == 0, nothing to do, return

    # Recursive Call 1: hanoi(n-1, from_peg, to_peg_as_aux, aux_peg_as_to)
    # Move n-1 disks from source (s1) to auxiliary (s2), using destination (s3) as temp.
    # So, new (source, aux, dest) = (s1, s3, s2)
    addi a0, s0, -1     # n-1
    mv a1, s1           # original from_peg remains source
    mv a2, s3           # original to_peg becomes new auxiliary
    mv a3, s2           # original aux_peg becomes new destination
    call torre_de_hanoi

    # Print move: "Mover disco N da torre FROM para a torre TO"
    # N is s0 (disk for current frame), FROM is s1, TO is s3
    la a0, str_mover_disco
    call putstr_no_newline

    addi a0, s0, '0'    # Convert disk number (s0, which is 1-9) to char
    call putchar

    la a0, str_da_torre
    call putstr_no_newline

    mv a0, s1           # from_peg char for this move
    call putchar

    la a0, str_para_a_torre
    call putstr_no_newline

    mv a0, s3           # to_peg char for this move
    call putchar

    li a0, '\n'         # Newline character
    call putchar

    # Recursive Call 2: hanoi(n-1, aux_peg, from_peg_as_aux, to_peg)
    # Move n-1 disks from auxiliary (s2) to destination (s3), using source (s1) as temp.
    # So, new (source, aux, dest) = (s2, s1, s3)
    addi a0, s0, -1     # n-1
    mv a1, s2           # original aux_peg becomes new source
    mv a2, s1           # original from_peg becomes new auxiliary
    mv a3, s3           # original to_peg remains destination
    call torre_de_hanoi

hanoi_epilogue:
    lw s3, 12(sp)
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32     # Deallocate stack space
    ret

#-------------------------------------------------------------------------------
# Helper: void putstr_no_newline(const char *str); a0: str
# Prints a null-terminated string without a trailing newline.
#-------------------------------------------------------------------------------
putstr_no_newline:
    addi sp, sp, -16    # Stack for ra, s0 (ptr), s1 (len)
    sw ra, 12(sp)
    sw s0, 8(sp)        # s0 will be current scan pointer
    sw s1, 4(sp)        # s1 will be length

    mv s0, a0           # s0 = start of string (argument)
    mv t5, a0           # Use t5 to hold the original start address of string for printing
    li s1, 0            # length = 0

str_len_loop:
    lbu t0, 0(s0)       # Load byte
    beqz t0, str_len_done # If null, end of string
    addi s0, s0, 1      # Advance scan pointer
    addi s1, s1, 1      # Increment length
    j str_len_loop

str_len_done:
    # String address for syscall is in t5, length in s1
    li a0, 1            # File descriptor 1 (stdout)
    mv a1, t5           # Buffer address (original start of string)
    mv a2, s1           # Number of bytes (length)
    li a7, 64           # Syscall number for write
    ecall

    lw s1, 4(sp)        # Restore caller's s1
    lw s0, 8(sp)        # Restore caller's s0
    lw ra, 12(sp)       # Restore caller's ra
    addi sp, sp, 16     # Deallocate stack
    ret

#-------------------------------------------------------------------------------
# Helper: void putchar(char c); a0: char
# Prints a single character.
#-------------------------------------------------------------------------------
putchar:
    addi sp, sp, -16    # Allocate 16 bytes on stack (e.g. to store the char for syscall)
                        # No ra save needed if this is a true leaf and makes no 'call'.
                        # For safety, if environment is tricky or if it might call another func later:
    sw ra, 12(sp)       # Save ra (optional for simple leaf, safer practice)
    sb a0, 8(sp)        # Store char from a0 onto the stack (e.g. at sp + 8)

    li a0, 1            # File descriptor 1 (stdout)
    add a1, sp, 8       # Buffer address (pointer to the char on stack)
    li a2, 1            # Number of bytes = 1
    li a7, 64           # Syscall number for write
    ecall

    lw ra, 12(sp)       # Restore ra
    addi sp, sp, 16     # Deallocate stack
    ret

#-------------------------------------------------------------------------------
# void puts(const char *str); a0: str
# Prints a string followed by a newline. (Original version for general use)
#-------------------------------------------------------------------------------
puts:
    addi sp, sp, -16      # Adjust stack pointer for ra, s0, s1
    sw ra, 12(sp)         # Save return address
    sw s0, 8(sp)          # s0 for string pointer (scan)
    sw s1, 4(sp)          # s1 for string length
    
    mv t5, a0             # t5 = original string start
    mv s0, a0             # s0 = current scan pointer
    li s1, 0              # s1 = length = 0

puts_calculate_length_loop:
    lbu t0, 0(s0)         # Load byte from string
    beqz t0, puts_length_calculated # If byte is null, length calculation done
    addi s0, s0, 1        # Increment string pointer
    addi s1, s1, 1        # Increment length
    j puts_calculate_length_loop

puts_length_calculated:
    # Write the string to stdout (fd=1)
    li a0, 1              # a0 = 1 (stdout file descriptor)
    mv a1, t5             # a1 = buffer address (original start of the string)
    mv a2, s1             # a2 = length of string
    li a7, 64             # a7 = 64 (syscall number for write)
    ecall

    # Write the newline character
    la a1, newline        # a1 = address of newline character string
    li a0, 1              # a0 = 1 (stdout)
    li a2, 1              # a2 = length 1 (for "\n" itself)
    li a7, 64             # a7 = 64 (syscall write)
    ecall

    lw s1, 4(sp)
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#-------------------------------------------------------------------------------
# char *gets(char *str); a0: buffer -> a0: buffer
#-------------------------------------------------------------------------------
gets:
    addi sp, sp, -16      # Adjust stack for ra, s0, s1
    sw ra, 12(sp)         # Save return address
    sw s0, 8(sp)          # s0 for buffer base pointer
    sw s1, 4(sp)          # s1 for current char index

    mv s0, a0             # s0 = str (buffer base)
    li s1, 0              # s1 = index = 0

gets_loop:
    li a0, 0              # a0 = 0 (stdin file descriptor)
    add a1, s0, s1        # a1 = &buffer[index] (address to store char)
    li a2, 1              # a2 = read 1 byte
    li a7, 63             # a7 = 63 (syscall number for read)
    ecall

    bltz a0, gets_end_or_error # If read error (a0 < 0)
    beqz a0, gets_end_or_error # If 0 bytes read (EOF)

    add t0, s0, s1        # t0 = &buffer[index]
    lbu t1, 0(t0)         # t1 = character read (use lbu for chars)

    li t2, '\n'           # Load newline character
    beq t1, t2, gets_terminate # If char is newline, terminate

    addi s1, s1, 1        # index++
    j gets_loop

gets_terminate:
    add t0, s0, s1        # t0 = &buffer[index] (current position of newline)
    sb zero, 0(t0)        # Null-terminate at the newline position
    j gets_return

gets_end_or_error:        # EOF or error
    add t0, s0, s1        # t0 = &buffer[index] (current end of string)
    sb zero, 0(t0)        # Null-terminate what's read so far

gets_return:
    mv a0, s0             # Return original buffer pointer in a0

    lw s1, 4(sp)
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#-------------------------------------------------------------------------------
# int atoi(const char *str); a0: str -> a0: int_value
#-------------------------------------------------------------------------------
atoi:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)          # s0 for string pointer
    sw s1, 4(sp)          # s1 for accumulated result
    sw s2, 0(sp)          # s2 for sign (1 or -1)

    mv s0, a0             # s0 = str
    li s1, 0              # s1 = result = 0
    li s2, 1              # s2 = sign = 1 (positive)

skip_whitespace_atoi:
    lbu t0, 0(s0)
    li t1, ' '
    beq t0, t1, increment_s0_and_skip_ws_atoi
    li t1, '\t'
    beq t0, t1, increment_s0_and_skip_ws_atoi
    # Add other whitespace checks if needed (\n, \r, etc.)
    j check_sign_atoi

increment_s0_and_skip_ws_atoi:
    addi s0, s0, 1
    j skip_whitespace_atoi

check_sign_atoi:
    lbu t0, 0(s0)
    li t1, '-'
    beq t0, t1, handle_negative_sign_atoi
    li t1, '+'
    beq t0, t1, increment_s0_and_continue_atoi
    j convert_digits_atoi

handle_negative_sign_atoi:
    li s2, -1
    # Fall through
increment_s0_and_continue_atoi:
    addi s0, s0, 1
    # Fall through

convert_digits_atoi:
    lbu t0, 0(s0)         # Load current character
    beqz t0, atoi_done    # If null terminator, done

    li t1, '0'
    blt t0, t1, atoi_done # If char < '0', not a digit
    li t1, '9'
    bgt t0, t1, atoi_done # If char > '9', not a digit

    li t2, '0'            # Load ASCII value of '0' into t2
    sub t0, t0, t2        # Convert char '0'-'9' to int 0-9 (t0 = digit)     # Convert char '0'-'9' to int 0-9 (t0 = digit)

    li t2, 10
    mul s1, s1, t2        # result = result * 10
    add s1, s1, t0        # result = result + digit

    addi s0, s0, 1        # Move to next character
    j convert_digits_atoi

atoi_done:
    mul a0, s1, s2        # Apply sign: result * sign
    
    lw s2, 0(sp)
    lw s1, 4(sp)
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

#-------------------------------------------------------------------------------
# char *itoa(int value, char *str_arg, int base);
# a0: value, a1: str_arg (output buffer), a2: base
# Returns: a0 = str_arg
#-------------------------------------------------------------------------------
itoa:
    addi sp, sp, -32      # Space for ra, s0-s5
    sw ra, 28(sp)
    sw s0, 24(sp)         # s0: value being converted
    sw s1, 20(sp)         # s1: current write pointer in output str_arg
    sw s2, 16(sp)         # s2: base
    sw s3, 12(sp)         # s3: original str_arg pointer (return value)
    sw s4, 8(sp)          # s4: pointer to internal_temp_buffer
    sw s5, 4(sp)          # s5: count of digits in internal_temp_buffer

    mv s0, a0             # s0 = value
    mv s3, a1             # s3 = original str_arg (arg a1)
    mv s1, s3             # s1 = current output pointer = str_arg
    mv s2, a2             # s2 = base

    la s4, itoa_internal_buffer # s4 points to internal scratchpad
    li s5, 0              # s5 = digit_count_in_temp = 0

    beqz s0, itoa_zero_case # Handle value == 0

itoa_nonzero:
    li t1, 10
    bne s2, t1, itoa_base_is_not_10

# --- Base 10 Path ---
itoa_base_is_10:
    bltz s0, itoa_base10_negative
    # Positive number or zero (zero already handled)
    j itoa_convert_base10_loop

itoa_base10_negative:
    li t0, '-'
    sb t0, 0(s1)          # Store '-' in output str_arg
    addi s1, s1, 1        # Advance output pointer
    neg s0, s0            # s0 = abs(value). If s0 was INT_MIN, it remains negative.
    # Fall through

itoa_convert_base10_loop: # s0 is value (abs or original positive)
    rem t0, s0, s2        # t0 = s0 % 10 (remainder)
    div s0, s0, s2        # s0 = s0 / 10 (quotient)
    
    bltz t0, itoa_b10_rem_neg # If remainder < 0 (can happen if original s0 was INT_MIN)
itoa_b10_rem_pos_continue:
    addi t0, t0, '0'      # Convert digit to char
    
    sb t0, 0(s4)          # Store char in internal_temp_buffer
    addi s4, s4, 1        # Advance temp_buffer pointer
    addi s5, s5, 1        # Increment digit count
    bnez s0, itoa_convert_base10_loop
    j itoa_copy_from_temp

itoa_b10_rem_neg:
    neg t0, t0            # Make remainder positive
    j itoa_b10_rem_pos_continue

# --- Other Base Path (e.g., Base 16, unsigned) ---
itoa_base_is_not_10: # Assuming base 16, treat s0 as unsigned
itoa_convert_other_base_loop:
    remu t0, s0, s2       # t0 = s0 % base (unsigned)
    divu s0, s0, s2       # s0 = s0 / base (unsigned)
    
    li t1, 10
    blt t0, t1, itoa_other_base_digit_is_numeric
    addi t0, t0, 'A' - 10 # Digit A-F
    j itoa_other_base_store_char
itoa_other_base_digit_is_numeric:
    addi t0, t0, '0'      # Digit 0-9
itoa_other_base_store_char:
    sb t0, 0(s4)          # Store char in internal_temp_buffer
    addi s4, s4, 1
    addi s5, s5, 1
    bnez s0, itoa_convert_other_base_loop
    j itoa_copy_from_temp

itoa_zero_case:
    li t0, '0'
    sb t0, 0(s4)          # Store '0' in internal_temp_buffer
    addi s4, s4, 1
    li s5, 1              # digit_count = 1
    # Fall through

itoa_copy_from_temp:
    # Digits are in internal_temp_buffer (pointed by s4, count s5), reversed.
    # Copy them to output str_arg (pointed by s1).
itoa_reverse_copy_loop:
    beqz s5, itoa_finalize_output # If count is 0, done

    addi s4, s4, -1       # Point s4 to last char written in temp
    lbu t0, 0(s4)         # Load char from temp
    sb t0, 0(s1)          # Store char into output str_arg
    addi s1, s1, 1        # Advance output pointer
    addi s5, s5, -1       # Decrement count
    j itoa_reverse_copy_loop

itoa_finalize_output:
    sb zero, 0(s1)        # Null-terminate the output string
    mv a0, s3             # Return original str_arg pointer

    lw s5, 4(sp)
    lw s4, 8(sp)
    lw s3, 12(sp)
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

#-------------------------------------------------------------------------------
# void exit(int code); a0: exit_code
#-------------------------------------------------------------------------------
exit:
    # Argument 'code' is already in a0
    li a7, 93             # Syscall number for exit
    ecall
    # This function does not return

#-------------------------------------------------------------------------------
.section .rodata
#-------------------------------------------------------------------------------
newline:
    .asciz "\n"

# Strings for optimized Tower of Hanoi printing
str_mover_disco:
    .asciz "Mover disco "
str_da_torre:
    .asciz " da torre "
str_para_a_torre:
    .asciz " para a torre "

#-------------------------------------------------------------------------------
.section .bss
#-------------------------------------------------------------------------------
.align 2 # Ensures 4-byte alignment (2^2)
itoa_internal_buffer: # Internal temporary buffer for itoa function
    .space 33 # Sufficient for 32-bit int string form, sign, and null.