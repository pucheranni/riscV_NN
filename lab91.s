.section .text
.globl linked_list_search
.globl puts
.globl gets
.globl atoi
.globl itoa
.globl exit

# linked_list_search function
# int linked_list_search(Node *head_node, int val);
#   a0: head_node (pointer to the first node)
#   a1: val (integer value to search for the sum)
#   Returns: a0 = index of the node if found, -1 otherwise
linked_list_search:
    addi sp, sp, -16      # Adjust stack pointer for ra, s0, s1, s2
    sw ra, 12(sp)         # Save return address
    sw s0, 8(sp)          # s0 will store current node pointer
    sw s1, 4(sp)          # s1 will store current index
    sw s2, 0(sp)          # s2 will store the target sum value (val)

    mv s0, a0             # s0 = head_node
    mv s2, a1             # s2 = val (value to search)
    li s1, 0              # s1 = index = 0

search_loop:
    beqz s0, not_found    # if current_node (s0) == NULL, goto not_found
    lw t0, 0(s0)          # t0 = current_node->val1
    lw t1, 4(s0)          # t1 = current_node->val2
    add t2, t0, t1        # t2 = val1 + val2 (sum of current node)
    
    beq t2, s2, found     # if sum == target_val, goto found
    
    lw s0, 8(s0)          # s0 = current_node->next (move to next node)
    addi s1, s1, 1        # index++
    j search_loop

found:
    mv a0, s1             # Return index in a0
    j ll_exit

not_found:
    li a0, -1             # Return -1 in a0

ll_exit:
    lw s2, 0(sp)          # Restore s2
    lw s1, 4(sp)          # Restore s1
    lw s0, 8(sp)          # Restore s0
    lw ra, 12(sp)         # Restore return address
    addi sp, sp, 16       # Adjust stack pointer back
    ret

# puts function
# void puts(const char *str);
#   a0: str (pointer to null-terminated string)
puts:
    addi sp, sp, -16      # Adjust stack pointer for ra, s0, s1
    sw ra, 12(sp)         # Save return address
    sw s0, 8(sp)          # s0 for string pointer
    sw s1, 4(sp)          # s1 for string length

    mv s0, a0             # s0 = str
    li s1, 0              # s1 = length = 0

calculate_length_loop:      # Calculate string length
    lb t0, 0(s0)          # Load byte from string
    beqz t0, length_calculated # If byte is null, length calculation done
    addi s0, s0, 1        # Increment string pointer
    addi s1, s1, 1        # Increment length
    j calculate_length_loop

length_calculated:
    sub s0, s0, s1        # Reset s0 to the start of the string (str - length)

    # Write the string to stdout (fd=1)
    li a0, 1              # a0 = 1 (stdout file descriptor)
    mv a1, s0             # a1 = buffer address (start of the string)
    mv a2, s1             # a2 = length of string
    li a7, 64             # a7 = 64 (syscall number for write)
    ecall

    # Write the newline character
    la a1, newline        # a1 = address of newline character
    li a0, 1              # a0 = 1 (stdout)
    li a2, 1              # a2 = length 1 (for "\n")
    li a7, 64             # a7 = 64 (syscall write)
    ecall

    # Restore registers and return
    lw s1, 4(sp)
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

# gets function
# char *gets(char *str);
#   a0: str (buffer to fill)
#   Returns: a0 = str (pointer to the filled buffer)
gets:
    addi sp, sp, -16      # Adjust stack for ra, s0, s1
    sw ra, 12(sp)         # Save return address
    sw s0, 8(sp)          # s0 for buffer base pointer
    sw s1, 4(sp)          # s1 for current character pointer offset/index

    mv s0, a0             # s0 = str (buffer base)
    li s1, 0              # s1 = index = 0

gets_loop:
    # Read one character from stdin (fd=0)
    li a0, 0              # a0 = 0 (stdin file descriptor)
    add a1, s0, s1        # a1 = &buffer[index] (address to store char)
    li a2, 1              # a2 = read 1 byte
    li a7, 63             # a7 = 63 (syscall number for read)
    ecall

    # ecall for read returns number of bytes read in a0, or <0 for error
    bltz a0, gets_end_or_error # If read error or EOF (a0 might be 0 for EOF from some systems)
    beqz a0, gets_end_or_error # If 0 bytes read (EOF)

    add t0, s0, s1        # t0 = &buffer[index]
    lb t1, 0(t0)          # t1 = character read

    li t2, '\n'           # Load newline character for comparison
    beq t1, t2, gets_terminate # If char is newline, terminate string

    addi s1, s1, 1        # index++
    j gets_loop

gets_terminate:           # Newline encountered, null-terminate here
    add t0, s0, s1        # t0 = &buffer[index] (current position of newline)
    sb zero, 0(t0)        # Null-terminate at the newline position
    j gets_return

gets_end_or_error:        # EOF or error, null-terminate what's read so far
    add t0, s0, s1        # t0 = &buffer[index] (current end of string)
    sb zero, 0(t0)        # Null-terminate

gets_return:
    mv a0, s0             # Return original buffer pointer in a0

    lw s1, 4(sp)
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

# atoi function
# int atoi(const char *str);
#   a0: str (pointer to null-terminated string representing an integer)
#   Returns: a0 = integer value
atoi:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)          # s0 for string pointer
    sw s1, 4(sp)          # s1 for accumulated result
    sw s2, 0(sp)          # s2 for sign (1 or -1)

    mv s0, a0             # s0 = str
    li s1, 0              # s1 = result = 0
    li s2, 1              # s2 = sign = 1 (positive)

skip_whitespace:
    lb t0, 0(s0)
    li t1, ' '
    beq t0, t1, increment_s0_and_skip_ws
    li t1, '\t'
    beq t0, t1, increment_s0_and_skip_ws
    j check_sign

increment_s0_and_skip_ws:
    addi s0, s0, 1
    j skip_whitespace

check_sign:
    lb t0, 0(s0)
    li t1, '-'
    beq t0, t1, handle_negative_sign
    li t1, '+'
    beq t0, t1, increment_s0_and_continue # Just skip '+'
    j convert_digits # No sign, or sign already handled

handle_negative_sign:
    li s2, -1             # sign = -1
    # Fall through to increment_s0_and_continue

increment_s0_and_continue:
    addi s0, s0, 1
    # Fall through to convert_digits

convert_digits:
    lb t0, 0(s0)          # Load current character
    beqz t0, atoi_done    # If null terminator, conversion is done

    li t1, '0'
    blt t0, t1, atoi_done # If char < '0', not a digit, done
    li t1, '9'
    bgt t0, t1, atoi_done # If char > '9', not a digit, done

    li t1, '0'
    sub t0, t0, t1        # Convert char '0'-'9' to int 0-9

    li t2, 10
    mul s1, s1, t2        # result = result * 10
    add s1, s1, t0        # result = result + digit

    addi s0, s0, 1        # Move to next character
    j convert_digits

atoi_done:
    mul a0, s1, s2        # Apply sign: result * sign
    
    lw s2, 0(sp)
    lw s1, 4(sp)
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

# itoa function
# char *itoa(int value, char *str, int base);
#   a0: value (integer to convert)
#   a1: str (buffer to store the string)
#   a2: base (10 or 16)
#   Returns: a0 = str (pointer to the beginning of the string in the buffer)
itoa:
    addi sp, sp, -32      # Space for ra, s0-s5 (7 words = 28 bytes, round to 32 for 16-byte alignment)
    sw ra, 28(sp)
    sw s0, 24(sp)         # s0: current value being converted
    sw s1, 20(sp)         # s1: current write pointer in output buffer (str)
    sw s2, 16(sp)         # s2: base
    sw s3, 12(sp)         # s3: original str pointer (for return value)
    sw s4, 8(sp)          # s4: pointer to current position in temp_buffer
    sw s5, 4(sp)          # s5: count of digits in temp_buffer

    mv s0, a0             # s0 = value
    mv s3, a1             # s3 = original str pointer (argument a1)
    mv s1, s3             # s1 = current output pointer, initially = original str pointer
    mv s2, a2             # s2 = base

    la s4, buffer         # s4 points to the start of the temporary buffer
    li s5, 0              # s5 = digit_count_in_temp_buffer = 0

    # Handle value == 0 as a special case
    bnez s0, itoa_nonzero
itoa_zero_case:
    li t0, '0'
    sb t0, 0(s4)          # Store '0' in temp_buffer
    addi s4, s4, 1        # Advance temp_buffer pointer
    li s5, 1              # digit_count = 1
    j itoa_copy_from_temp_to_output # Skip main conversion logic

itoa_nonzero:
    li t1, 10
    bne s2, t1, itoa_base_is_16 # If base is not 10, assume it's 16 for this problem

# --- Base 10 Path ---
itoa_base_is_10:
    bltz s0, itoa_base10_negative # If value is negative, handle sign
    # Positive number for base 10, or value became positive after neg
    j itoa_convert_base10_signed_loop

itoa_base10_negative:
    li t0, '-'
    sb t0, 0(s1)          # Store '-' character in the output string buffer
    addi s1, s1, 1        # Advance output string pointer
    neg s0, s0            # s0 = abs(original_value)
                          # If s0 was INT_MIN, it remains INT_MIN (still negative)
    # Fall through to the conversion loop for base 10 (signed magnitude)

itoa_convert_base10_signed_loop: # s0 is >=0, or INT_MIN if original was INT_MIN
    rem t0, s0, s2        # t0 = s0 % 10 (signed remainder)
    div s0, s0, s2        # s0 = s0 / 10 (signed division)
    
    bgez t0, base10_rem_positive # If remainder is non-negative, it's fine
    neg t0, t0            # If s0 was INT_MIN, remainder could be negative; make it positive
base10_rem_positive:
    addi t0, t0, '0'      # Convert digit (0-9) to char '0'-'9'
    
    sb t0, 0(s4)          # Store digit char in temp_buffer (s4)
    addi s4, s4, 1        # Advance temp_buffer pointer
    addi s5, s5, 1        # Increment digit count in temp_buffer
    bnez s0, itoa_convert_base10_signed_loop # Loop if value (s0) not zero
    j itoa_copy_from_temp_to_output # All digits for base 10 are in temp_buffer

# --- Base 16 Path ---
itoa_base_is_16: # Value in s0 is original; treat as unsigned for base 16
                 # s1 is current output pointer (no '-' sign prepended for base 16)
itoa_convert_base16_unsigned_loop:
    remu t0, s0, s2       # t0 = s0 % 16 (unsigned remainder)
    divu s0, s0, s2       # s0 = s0 / 16 (unsigned division)
    
    # Convert t0 (0-15) to char '0'-'9', 'A'-'F'
    li t1, 10
    blt t0, t1, base16_digit_is_numeric
    addi t0, t0, 'A' - 10 # Hex digit is A-F (e.g., 10 becomes 'A')
    j base16_store_char_in_temp
base16_digit_is_numeric:
    addi t0, t0, '0'      # Hex digit is 0-9
base16_store_char_in_temp:
    sb t0, 0(s4)          # Store char in temp_buffer (s4)
    addi s4, s4, 1        # Advance temp_buffer pointer
    addi s5, s5, 1        # Increment digit count in temp_buffer
    bnez s0, itoa_convert_base16_unsigned_loop # Loop if value (s0) not zero
    # Fall through to copy digits from temp_buffer to output

itoa_copy_from_temp_to_output:
    # Digits are in temp_buffer in reverse order.
    # s4 currently points one byte *past* the last digit written in temp_buffer.
    # s5 is the count of digits in temp_buffer.
    # s1 points to where the number string should be written in the output buffer.
    # (For negative base 10, s1 was already advanced past the '-' sign).
itoa_reverse_temp_and_copy_loop:
    beqz s5, itoa_finalize_output # If no more digits in temp_buffer to copy, finish up

    addi s4, s4, -1         # Point s4 to the last (leftmost) char in temp_buffer to copy
    lb t0, 0(s4)            # Load char from temp_buffer
    sb t0, 0(s1)            # Store char into s1 (current output buffer position)
    addi s1, s1, 1          # Advance s1 (output buffer pointer)
    addi s5, s5, -1         # Decrement count of digits remaining in temp_buffer
    j itoa_reverse_temp_and_copy_loop

itoa_finalize_output:
    sb zero, 0(s1)          # Null-terminate the string at the current s1 position
    mv a0, s3               # Return the original str pointer (saved in s3)

    # Epilogue: Restore saved registers
    lw s5, 4(sp)
    lw s4, 8(sp)
    lw s3, 12(sp)
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32       # Adjust stack pointer back
    ret

# exit function
# void exit(int code);
#   a0: code (exit status code)
exit:
    # Argument 'code' is already in a0
    li a7, 93             # a7 = 93 (syscall number for exit)
    ecall                 # Make the syscall

.section .rodata
newline:
    .asciz "\n"

.section .bss
.align 4 # Word alignment is 4 bytes (2^2), .align 2 means 2^2 = 4 byte alignment
buffer: # Temporary buffer for itoa
    .space 33 # Max 32-bit integer in binary is 32 digits + null. Base 10 is ~10 digits.
              # 33 is safe for null termination and potential sign.