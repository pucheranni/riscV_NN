# RISC-V 32-bit Assembly Program for IrisNet Inference

.equ SYSCALL_READ, 63
.equ SYSCALL_WRITE, 64
.equ SYSCALL_EXIT, 93

.data
# String literals for parsing and output
newline: .asciz "\n"
comma: .asciz ","
open_bracket: .asciz "["
close_bracket: .asciz "]"
open_curly: .asciz "{"
close_curly: .asciz "}"
colon: .asciz ":"
quote: .asciz "\""
space: .asciz " " # For potential future use, not strictly needed by parser now

# Buffers for parsed data
# Max 10 layers, each size stored as a 4-byte integer
layer_sizes: .space 40 # Max 10 layers * 4 bytes/int
num_layers: .word 0

# Max input features (e.g., 4 for Iris)
# Max neurons per layer (e.g., 30 for a hidden layer in example 2)
# Activations will be stored as 8-bit signed integers, but accessed as words for processing convenience
# Max total neurons across all layers could be estimated.
# Example 1: 4+8+15+3 = 30 neurons. Example 2: 4+30+20+10+3 = 67 neurons
# Let's allocate space for activations. Max neurons in a single layer * 4 bytes (to hold them as words temporarily during computation)
# Max neurons in one layer could be around 30-50. Let's use 64 as a safe upper bound for any single layer's neuron count.
# We need two buffers for activations: one for a_prev and one for a_curr, or manage pointers carefully.
# Let's plan for storing all activations in one large buffer, indexed by layer.
# Or, more simply, current_activations and prev_activations buffers.
# Max neurons in any layer (e.g. 30 in example 2) * 1 byte/activation = 30 bytes.
# We'll use word-aligned buffers for easier access during computation before converting back to byte.
# Max 50 neurons in any given layer for activations.
prev_layer_activations: .space 200 # Max 50 neurons * 4 bytes/neuron (stored as words during computation)
current_layer_activations: .space 200 # Max 50 neurons * 4 bytes/neuron

# Weights: Stored as 8-bit signed integers.
# Example 1: l1 (4x8=32), l2 (8x15=120), l3 (15x3=45). Total = 32+120+45 = 197 weights.
# Example 2: l1 (4x30=120), l2 (30x20=600), l3 (20x10=200), l4 (10x3=30). Total = 950 weights.
# Max weights: Let's estimate 1000 weights * 1 byte/weight = 1000 bytes.
# This needs to be word aligned if accessed as words, but weights are bytes.
# We'll store them as bytes.
weights_storage: .space 1000 # Max 1000 weights

# For outputting the result (a single digit '0', '1', or '2' followed by newline)
output_buffer: .space 2 # For digit + newline (or just digit if that's preferred)
result_char: .byte 0 # To store the final character '0', '1', or '2'
# newline_char: .byte '\n' # For printing newline after result

# Debugging strings
debug_msg_parsing_arch: .asciz "Parsing architecture\n"
debug_msg_parsing_weights: .asciz "Parsing weights\n"
debug_msg_parsing_input: .asciz "Parsing input vector\n"
debug_msg_forward_pass: .asciz "Running forward pass\n"
debug_msg_argmax: .asciz "Running argmax\n"
debug_int_prefix: .asciz "INT: "
debug_int_suffix: .asciz "\n"


.bss
# Input buffer for the entire string from stdin
# Max length: Arch (e.g., "4,8,15,3" ~20 chars) + Weights (can be very long, e.g. example 2 has ~3KB) + Input (e.g., "59,30,51,18" ~20 chars)
# Let's allocate 4KB for the input string.
input_string_buffer: .space 4096

.text
.global _start

# --- Register Usage Plan ---
# s0: Pointer to current position in input_string_buffer
# s1: Pointer to layer_sizes array
# s2: Pointer to weights_storage
# s3: Pointer to prev_layer_activations
# s4: Pointer to current_layer_activations
# s5: Number of layers
# s6, s7, s8, s9, s10, s11: General purpose saved registers for loops, counts, addresses within functions.

_start:
    # Initialize stack pointer (specific to environment, usually done by crt0)
    # For qemu, it's often pre-initialized or we can set it high.
    # For simplicity in this environment, we might not need deep stack usage if we manage data globally.
    # However, good practice dictates setting it up if functions will use stack frames.
    # lui sp, %hi(_stack_end) # Assuming a linker script defines _stack_end
    # addi sp, sp, %lo(_stack_end)

    # Store return address and saved registers if _start is treated like a C main
    # For baremetal/qemu direct execution, not strictly needed unless calling other complex functions
    # that might clobber them and expecting _start to resume.

    # For now, we'll proceed assuming s registers are safe until we call other functions
    # that might use them without saving.

    # --- Placeholder for actual logic ---
    # This is where calls to parsing, forward pass, argmax, and print will go.
    # For now, just exit.

    # Example: Load address of input_string_buffer to a0 for read syscall
    la a0, input_string_buffer
    # ... rest of the program logic will follow the plan ...


    # Example usage (will be replaced by actual program logic):
    # 1. Read input
    # la a0, input_string_buffer # Buffer to read into
    # li a1, 4096                # Max length to read
    # call read_full_input

    # 2. Print a character (e.g., the first char of input or a test char)
    # lb a0, input_string_buffer # Character to print
    # call print_char_stdout

    # 3. Print a string (e.g. a debug message)
    # la a0, debug_msg_parsing_arch
    # call print_string_stdout

    # Exit program
    li a7, SYSCALL_EXIT
    ecall

#-------------------------------------------------------------------------------
# Syscall Wrappers
#-------------------------------------------------------------------------------

# read_full_input: Reads from stdin into a buffer.
# Arguments:
#   a0: Pointer to the buffer.
#   a1: Maximum number of bytes to read.
# Returns:
#   a0: Number of bytes read (from syscall).
# Clobbers: a0, a1, a2, a7, temporaries used by ecall.
read_full_input:
    mv t0, ra # Save ra, as ecall might clobber it (though usually not for Linux syscalls)
              # For robustness, especially if this becomes a deeper utility.

    li a2, 0  # File descriptor for stdin is 0. Store in a2 as per original snippet (though a0 is typical for fd)
              # Correcting to use a0 for fd as is standard for Linux syscalls.
              # The problem description snippet had `li a0, 0` for fd.
    mv a2, a1 # syscall read expects count in a2, problem snippet has `li a2, 1` which is for single char.
              # For reading a string, a2 should be the length.
    mv a1, a0 # syscall read expects buffer in a1.
    li a0, 0  # syscall read expects file descriptor in a0.

    li a7, SYSCALL_READ         # syscall number for read
    ecall                       # Make the syscall

    # a0 now contains the number of bytes read or an error code.
    mv ra, t0 # Restore ra
    ret

# print_char_stdout: Prints a single character to stdout.
# Arguments:
#   a0: The character to print (as an integer/ASCII value).
# Returns: None
# Clobbers: a0, a1, a2, a7, temporaries used by ecall.
print_char_stdout:
    mv t0, ra

    # To print a single character, we need its address.
    # We can store it temporarily on the stack or use a dedicated data section byte.
    # Using result_char which is already defined.
    la t1, result_char
    sb a0, 0(t1) # Store the character from a0 into result_char

    mv a1, t1                   # a1: address of the character to print
    li a2, 1                    # a2: length (1 character)
    li a0, 1                    # a0: file descriptor for stdout
    li a7, SYSCALL_WRITE        # syscall number for write
    ecall

    mv ra, t0
    ret

# print_string_stdout: Prints a null-terminated string to stdout.
# Arguments:
#   a0: Pointer to the null-terminated string.
# Returns: None
# Clobbers: a0, a1, a2, a3, a7, temporaries.
print_string_stdout:
    mv t0, ra   # Save ra
    mv t1, a0   # t1 = current char pointer

    # Calculate string length
    li t2, 0    # t2 = length
strlen_loop:
    lb t3, 0(t1)
    beq t3, zero, strlen_done
    addi t1, t1, 1
    addi t2, t2, 1
    j strlen_loop
strlen_done:

    # Now print the string
    mv a1, a0                   # a1: address of the string
    mv a2, t2                   # a2: length of the string
    li a0, 1                    # a0: file descriptor for stdout
    li a7, SYSCALL_WRITE
    ecall

    mv ra, t0   # Restore ra
    ret

#-------------------------------------------------------------------------------
# String / Parsing Utilities
#-------------------------------------------------------------------------------

# parse_int: Parses a signed integer from a string.
# The string is NOT null-terminated; parsing stops at the first non-digit
# character (after an optional leading '-' or '+').
# Arguments:
#   a0: Pointer to the start of the string segment to parse.
#   a1: Max number of characters to check in this segment (acts as a boundary).
# Returns:
#   a0: The parsed integer.
#   a1: Pointer to the character immediately after the parsed integer.
# Clobbers: t0-t6
# Registers used:
#   t0: current character
#   t1: accumulated result
#   t2: sign (1 for positive, -1 for negative)
#   t3: character pointer (current position)
#   t4: loop counter / boundary check
#   t5: temporary for ASCII arithmetic
parse_int:
    mv t3, a0      # t3 = current character pointer
    li t1, 0       # t1 = accumulated result = 0
    li t2, 1       # t2 = sign = 1 (positive)
    li t4, 0       # t4 = characters processed count

    # Check for sign
    lb t0, 0(t3)
    beq t4, a1, parse_int_done # Reached max length boundary
    li t5, '-'
    beq t0, t5, parse_int_negative
    li t5, '+'
    beq t0, t5, parse_int_positive_sign

parse_int_skip_sign_check:
    # Loop to read digits
parse_int_loop:
    beq t4, a1, parse_int_done # Reached max length boundary
    lb t0, 0(t3)

    # Check if character is a digit
    li t5, '0'
    blt t0, t5, parse_int_done # Not a digit (less than '0')
    li t5, '9'
    bgt t0, t5, parse_int_done # Not a digit (greater than '9')

    # Convert char to digit value
    li t5, '0'
    sub t0, t0, t5 # t0 = digit value

    # Accumulate result: result = result * 10 + digit
    li t5, 10
    mul t1, t1, t5 # result = result * 10
    add t1, t1, t0 # result = result + digit

    addi t3, t3, 1   # Advance character pointer
    addi t4, t4, 1   # Increment processed char count
    j parse_int_loop

parse_int_negative:
    li t2, -1      # Set sign to negative
    addi t3, t3, 1 # Skip '-'
    addi t4, t4, 1
    j parse_int_skip_sign_check

parse_int_positive_sign:
    addi t3, t3, 1 # Skip '+'
    addi t4, t4, 1
    j parse_int_skip_sign_check

parse_int_done:
    # Apply sign
    mv t5, t2
    li t6, -1
    bne t5, t6, parse_int_final_value
    neg t1, t1     # Apply negative sign if t2 was -1

parse_int_final_value:
    mv a0, t1      # Return value in a0
    mv a1, t3      # Return updated pointer in a1
    ret

# find_char: Finds the next occurrence of a character in a string segment.
# Arguments:
#   a0: Pointer to the start of the string segment.
#   a1: The character to find.
#   a2: Max number of characters to search (boundary).
# Returns:
#   a0: Pointer to the found character, or pointer to end of segment if not found.
#   a1: Flag: 0 if found, 1 if not found (or reached boundary).
# Clobbers: t0, t1, t2, t3
# Registers used:
#   t0: current character from string
#   t1: char to find
#   t2: current pointer
#   t3: counter for max length
find_char:
    mv t1, a1      # t1 = char to find
    mv t2, a0      # t2 = current pointer
    li t3, 0       # t3 = characters searched

find_char_loop:
    beq t3, a2, find_char_not_found_boundary # Reached max length
    lb t0, 0(t2)
    beq t0, zero, find_char_not_found_null # Null terminator also means not found within typical use
    beq t0, t1, find_char_found

    addi t2, t2, 1
    addi t3, t3, 1
    j find_char_loop

find_char_found:
    mv a0, t2
    li a1, 0       # Found
    ret

find_char_not_found_null: # If we hit null before boundary and didn't find char
    mv a0, t2      # Pointer to the null char
    li a1, 1       # Not found
    ret

find_char_not_found_boundary: # If we hit boundary before finding char
    mv a0, t2      # Pointer to where search stopped (end of boundary)
    li a1, 1       # Not found
    ret

#-------------------------------------------------------------------------------
# Input Parsing - Phase 1: Architecture and Input Vector
#-------------------------------------------------------------------------------

# parse_layer_sizes: Parses the architecture string (e.g., "4,8,15,3")
# Arguments:
#   a0: Pointer to the start of the architecture string.
#   a1: Pointer to the end of the architecture string (e.g., newline char).
#   s1: (Implicit global) Pointer to layer_sizes array in .data.
#   num_layers: (Implicit global) Address of num_layers word in .data.
# Modifies:
#   layer_sizes array, num_layers variable.
# Returns:
#   a0: Pointer to the char after the last parsed part of this line (e.g. newline or further).
# Clobbers: t0-t6, a0-a3 (as per called functions)
# Registers used:
#   s6: Current pointer in input string.
#   s7: Pointer to layer_sizes array for storing.
#   s8: Count of layers parsed.
#   s9: Pointer to end of architecture string segment.
parse_layer_sizes:
    # Prologue: Save callee-saved registers if they are modified and need to be preserved for the caller.
    # For this function, we'll use s6-s9. Let's assume they are managed by the caller or are dedicated.
    # If this were a general utility, stack saving would be needed.
    # For now, we directly use them as assigned.

    mv s6, a0      # s6 = current_ptr = start of arch string
    mv s9, a1      # s9 = end_ptr for this segment
    la s7, layer_sizes # s7 = pointer to layer_sizes storage
    li s8, 0       # s8 = layer_count = 0

parse_layer_loop:
    # Check if current_ptr has reached or passed end_ptr
    bgeu s6, s9, parse_layer_done # Unsigned comparison for pointers

    # Prepare for parse_int: a0 = string_ptr, a1 = max_len
    mv a0, s6
    sub a1, s9, s6 # Max length is remaining part of the segment

    call parse_int # a0 = parsed_int, a1 = ptr_after_int

    # Store the parsed layer size
    sw a0, 0(s7)
    addi s7, s7, 4 # Move to next slot in layer_sizes array
    addi s8, s8, 1 # Increment layer count

    mv s6, a1      # Update current_ptr to pointer after int

    # Check for comma or end of segment
    bgeu s6, s9, parse_layer_done # If ptr_after_int is at or beyond end, we are done.
    lb t0, 0(s6)   # Load char at current_ptr
    li t1, ','
    beq t0, t1, parse_layer_skip_comma # If comma, skip it and continue
    # If not a comma and not end of segment, it's unexpected, or end of numbers.
    # For robust parsing, might check if it's newline or other delimiter.
    # Assuming valid input, if not comma, it must be the end of numbers for this line.
    j parse_layer_done

parse_layer_skip_comma:
    addi s6, s6, 1 # Skip comma
    j parse_layer_loop

parse_layer_done:
    # Store the number of layers found
    la t0, num_layers
    sw s8, 0(t0)

    mv a0, s6 # Return pointer to position after parsing this line
    ret

# parse_initial_activations: Parses the input vector string (e.g., "59,30,51,18")
# Arguments:
#   a0: Pointer to the start of the input vector string.
#   a1: Pointer to the end of the input vector string.
#   s3: (Implicit global) Pointer to prev_layer_activations array in .data.
#       (This will store a^[0])
# Modifies:
#   prev_layer_activations array.
# Returns:
#   a0: Pointer to the char after the last parsed part of this line.
# Clobbers: t0-t6, a0-a3 (as per called functions)
# Registers used: (similar to parse_layer_sizes)
#   s6: Current pointer in input string.
#   s7: Pointer to prev_layer_activations array for storing.
#   s8: Count of activations parsed (for debugging/validation, not strictly stored globally here).
#   s9: Pointer to end of input vector string segment.
parse_initial_activations:
    mv s6, a0      # s6 = current_ptr
    mv s9, a1      # s9 = end_ptr
    la s7, prev_layer_activations # s7 = pointer to activation storage

    # s8 could count parsed activations if needed, but not strictly required by spec to store count.
    # The number of input activations should match layer_sizes[0].

parse_activations_loop:
    bgeu s6, s9, parse_activations_done

    mv a0, s6
    sub a1, s9, s6
    call parse_int # a0 = parsed_int (activation value), a1 = ptr_after_int

    # Store the parsed activation value.
    # Activations are 8-bit signed, but we store them as words for now for easier processing
    # during matrix multiplication. They will be treated as 8-bit values logically.
    # Or, if strict 8-bit storage is required from the start:
    #   slli t2, a0, 24
    #   srai t2, t2, 24 # Ensure it's a valid 8-bit signed value before storing
    #   sb t2, 0(s7)
    #   addi s7, s7, 1 # Move to next byte slot
    # For now, let's store as words, and handle 8-bit nature during computation.
    sw a0, 0(s7)
    addi s7, s7, 4 # Move to next word slot

    mv s6, a1      # Update current_ptr

    bgeu s6, s9, parse_activations_done
    lb t0, 0(s6)
    li t1, ','
    beq t0, t1, parse_activations_skip_comma
    j parse_activations_done

parse_activations_skip_comma:
    addi s6, s6, 1
    j parse_activations_loop

parse_activations_done:
    mv a0, s6 # Return pointer
    ret

#-------------------------------------------------------------------------------
# Input Parsing - Phase 2: Weights
#-------------------------------------------------------------------------------
# parse_weights: Parses the JSON-like weight string by extracting all numbers.
# Arguments:
#   a0: Pointer to the start of the weights string. (current_char_ptr)
#   a1: Pointer to the end of the weights string. (boundary_ptr)
#   a2: Pointer to the buffer where weights will be stored. (weights_storage_ptr)
# Modifies:
#   The buffer pointed to by a2.
# Returns:
#   a0: Pointer to the char after the last processed part of the string.
#   a2: Pointer to the next available spot in the weights_storage buffer.
# Clobbers: t0-t6 (from parse_int and locally), a0, a1 (from parse_int).
# Preserves s-registers by saving/restoring s0, s1 if used.
parse_weights:
    # Save callee-saved registers we will use for persistent pointers
    addi sp, sp, -12
    sw ra, 0(sp) # Save return address
    sw s0, 4(sp) # s0 will be our persistent current_char_ptr for the input string
    sw s1, 8(sp) # s1 will be our persistent weights_storage_ptr

    mv s0, a0      # s0 = current_char_ptr, from argument a0
    mv t5, a1      # t5 = end_char_ptr (boundary), from argument a1
    mv s1, a2      # s1 = current_weights_storage_ptr, from argument a2

parse_weights_main_loop:
    bgeu s0, t5, parse_weights_exit # If current_ptr >= end_ptr, done with the segment.

    lb t0, 0(s0) # Load current character

    # Check if the character could be the start of a number
    li t1, '-'
    beq t0, t1, parse_weights_is_number # If '-', it's part of a number
    li t1, '0'
    blt t0, t1, parse_weights_skip_current_char # If less than '0' (and not '-'), skip
    li t1, '9'
    bgt t0, t1, parse_weights_skip_current_char # If greater than '9', skip
    # If execution reaches here, t0 is a digit '0'-'9'.

parse_weights_is_number:
    # It's a number or starts with '-'
    # Prepare for parse_int: a0 = string_ptr, a1 = max_len
    mv a0, s0
    sub a1, t5, s0 # Max length is remaining part of the segment

    call parse_int # a0 = parsed_int, a1 = ptr_after_int from parse_int

    # Clamp the parsed integer (in a0) to 8-bit signed range [-128, 127]
    li t2, 127  # Max signed 8-bit
    li t3, -128 # Min signed 8-bit

    bgt a0, t2, pw_clamp_positive
    blt a0, t3, pw_clamp_negative
    j pw_store_value

pw_clamp_positive:
    mv a0, t2
    j pw_store_value

pw_clamp_negative:
    mv a0, t3
    # Fall through

pw_store_value:
    sb a0, 0(s1)   # Store the (clamped) 8-bit value into weights_storage
    addi s1, s1, 1 # Increment weights_storage_ptr

    mv s0, a1      # Update current_char_ptr from parse_int's return (ptr_after_int)
    j parse_weights_main_loop # Continue scanning from the new position

parse_weights_skip_current_char:
    addi s0, s0, 1 # Skip the current non-numeric, non-sign character
    j parse_weights_main_loop

parse_weights_exit:
    mv a0, s0      # Return updated current_char_ptr
    mv a2, s1      # Return updated weights_storage_ptr

    # Restore callee-saved registers and return address
    lw s1, 8(sp)
    lw s0, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 12
    ret

#-------------------------------------------------------------------------------
# Neural Network Core Logic
#-------------------------------------------------------------------------------

# sign_extend_8_to_32: Correctly sign-extends an 8-bit value (in lower 8 bits of a0) to 32 bits.
# Argument:
#   a0: Register containing the 8-bit value in its lower 8 bits.
# Returns:
#   a0: The 32-bit sign-extended value.
# Clobbers: a0 (obviously)
sign_extend_8_to_32:
    slli a0, a0, 24 # Shift the 8-bit value to the most significant bits
    srai a0, a0, 24 # Shift it back with arithmetic (sign-extending) right shift
    ret

# clamp_to_8bit_signed: Clamps a 32-bit value to the signed 8-bit range [-128, 127].
# Argument:
#   a0: The 32-bit value to clamp.
# Returns:
#   a0: The clamped 8-bit value (still in a 32-bit register).
# Clobbers: a0, t0, t1
clamp_to_8bit_signed:
    li t0, 127  # Max value for signed 8-bit
    li t1, -128 # Min value for signed 8-bit

    bgt a0, t0, clamp_val_positive
    blt a0, t1, clamp_val_negative
    ret # Value is already in range

clamp_val_positive:
    mv a0, t0
    ret
clamp_val_negative:
    mv a0, t1
    ret

# matrix_vector_multiply_and_relu:
# Performs W * a_prev + ReLU (or just W * a_prev for the output layer).
# Arguments:
#   a0: Pointer to the current layer's weight matrix (W). Rows of W are contiguous.
#   a1: Pointer to the previous layer's activation vector (a_prev). (Stored as words)
#   a2: Pointer to store the current layer's activation vector (a_curr). (Stored as words)
#   a3: Number of neurons in the current layer (num_neurons_curr, rows of W).
#   a4: Number of neurons in the previous layer (num_neurons_prev, columns of W / size of a_prev).
#   a5: Flag: 0 to apply ReLU, 1 to skip ReLU (for output layer).
#
# Registers used:
#   s0: Pointer to current row in W.
#   s1: Pointer to a_prev.
#   s2: Pointer to a_curr.
#   s3: Outer loop counter (i for current layer neurons).
#   s4: Inner loop counter (j for previous layer neurons).
#   s5: num_neurons_curr.
#   s6: num_neurons_prev.
#   s7: is_output_layer_flag (from a5).
#   t0, t1, t2, t3, t4: Temporaries for values, addresses.
matrix_vector_multiply_and_relu:
    # Save callee-saved registers
    addi sp, sp, -32
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    sw s2, 12(sp)
    sw s3, 16(sp)
    sw s4, 20(sp)
    sw s5, 24(sp)
    sw s6, 28(sp)
    # s7 is also used, need to save it if it's considered callee-saved by convention.
    # For RV32I, s0-s11 are callee-saved. So s7 needs saving.
    # Let's re-evaluate register usage or stack space.
    # addi sp, sp, -36; sw s7, 32(sp) -- if using s7.
    # Alternative: use fewer s-registers or map a5 to a t-register if its scope is limited.
    # For now, assuming s7 is available or this function manages it.
    # It is better to use t-registers for arguments if they are not needed across the function span.
    # Let's adjust stack frame and save s7.
    addi sp, sp, -4 # adjust for one more s reg
    sw s7, 32(sp)   # s7 now at 32(sp) from original sp


    mv s0, a0      # s0 = W_ptr
    mv s1, a1      # s1 = a_prev_ptr
    mv s2, a2      # s2 = a_curr_ptr
    mv s5, a3      # s5 = num_neurons_curr
    mv s6, a4      # s6 = num_neurons_prev
    mv s7, a5      # s7 = is_output_layer_flag

    li s3, 0       # i = 0 (current layer neuron index)
outer_loop_neurons: # Loop over each neuron in the current layer
    beq s3, s5, outer_loop_done # if i == num_neurons_curr, exit outer loop

    li t0, 0       # t0 = accumulated_sum (Z_i) = 0
    li s4, 0       # j = 0 (previous layer neuron index)
inner_loop_weights: # Loop over each weight/activation in the previous layer
    beq s4, s6, inner_loop_done # if j == num_neurons_prev, exit inner loop

    # Load weight W_ij: Weights are 8-bit signed bytes.
    # s0 points to current row of W. Offset by j to get W_ij.
    # W is num_neurons_curr x num_neurons_prev.
    # Address of W_ij = W_base + (i * num_neurons_prev + j) * sizeof(byte)
    # Current s0 points to W_i0 (start of current row i). So just add j.
    add t1, s0, s4 # t1 = address of W_ij
    lb t2, 0(t1)   # t2 = W_ij (8-bit value)
    # Sign extend W_ij to 32-bit for multiplication
    slli t2, t2, 24
    srai t2, t2, 24 # t2 is now sign-extended W_ij

    # Load activation a_prev_j: Activations are stored as words (4 bytes).
    # s1 points to a_prev_0. Offset by j * 4.
    slli t1, s4, 2 # t1 = j * 4
    add t1, s1, t1 # t1 = address of a_prev_j
    lw t3, 0(t1)   # t3 = a_prev_j (32-bit value, but logically 8-bit signed)
    # Sign extend a_prev_j to 32-bit (it's already stored as word, but ensure interpretation)
    # The problem states "handle sign extension before performing comparisons (like in the ReLU function)"
    # and "All weights and intermediate values must be treated as 8-bit signed integers".
    # When loaded as lw, if it was stored as a byte then sign-extended to word, it's fine.
    # If stored as a word from a calculation, it should already be correctly signed.
    # For safety, especially if a_prev_j was result of ReLU (max(0,x)), it might just be positive.
    # Let's assume values in prev_layer_activations are already correctly signed 32-bit words
    # that represent the 8-bit conceptual values. If they were stored using `sb` then `lw` without
    # `lb` then sign-extend, they might not be correctly sign-extended if positive.
    # The `parse_initial_activations` stores them as `sw`.
    # ReLU output will also be `sw`.
    # Let's be explicit with sign extension for activations if they are conceptually 8-bit.
    # This should have been done when they were produced by ReLU or parsing.
    # For now, assume t3 is a 32-bit value that correctly represents the signed 8-bit concept.
    # If not, it needs `slli t3, t3, 24; srai t3, t3, 24` here.
    # Given they are outputs of ReLU or initial parse (which should ensure clamping/signing),
    # they are likely fine as 32-bit values.

    mul t4, t2, t3 # t4 = W_ij * a_prev_j (product can exceed 8-bit range)
    add t0, t0, t4 # Z_i = Z_i + (W_ij * a_prev_j)

    addi s4, s4, 1 # j++
    j inner_loop_weights
inner_loop_done:
    # Z_i (in t0) is now computed.
    # Clamp Z_i to 8-bit signed range [-128, 127] as per "intermediate values" rule.
    mv a0, t0      # Pass Z_i to clamp function
    call clamp_to_8bit_signed # a0 = clamped Z_i
    mv t0, a0      # t0 = clamped Z_i

    # Apply ReLU if not output layer
    # s7 is is_output_layer_flag. If 0, apply ReLU. If 1, skip.
    beq s7, zero, apply_relu # If s7 == 0 (false, so not output layer), apply ReLU
    mv t1, t0      # Skip ReLU: a_curr_i = Z_i (clamped)
    j store_activation

apply_relu:
    # ReLU: max(0, Z_i). Z_i is in t0.
    # Value in t0 is already sign-extended 32-bit representation of an 8-bit value.
    mv t1, t0      # t1 = Z_i
    sgtz t2, t1    # t2 = (Z_i > 0) ? 1 : 0
    mul t1, t1, t2 # if Z_i > 0, t1 = Z_i * 1 = Z_i. if Z_i <= 0, t1 = Z_i * 0 = 0.
                   # This works if Z_i is negative (becomes 0) or positive (remains).
                   # A simpler way: if (t1 < 0) t1 = 0;
    bltz t1, relu_set_zero # If t1 < 0, set to zero
    # else, t1 is already >= 0, so it's the ReLU output
    j store_activation
relu_set_zero:
    li t1, 0       # t1 = 0
    # Fall through to store_activation

store_activation:
    # Store t1 (which is a_curr_i) into current_layer_activations. Stored as a word.
    slli t2, s3, 2 # t2 = i * 4 (offset for word array)
    add t2, s2, t2 # t2 = address of a_curr_i
    sw t1, 0(t2)   # Store a_curr_i

    # Advance s0 to the next row of weights W
    # Each row has num_neurons_prev weights (bytes).
    add s0, s0, s6 # s0 += num_neurons_prev (since weights are bytes)

    addi s3, s3, 1 # i++
    j outer_loop_neurons
outer_loop_done:

    # Restore callee-saved registers
    lw s7, 32(sp) # Must match where it was stored relative to original sp
    lw s6, 28(sp)
    lw s5, 24(sp)
    lw s4, 20(sp)
    lw s3, 16(sp)
    lw s2, 12(sp)
    lw s1, 8(sp)
    lw s0, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 36 # Adjusted for s7 save

    ret

#-------------------------------------------------------------------------------
# Forward Pass Orchestration
#-------------------------------------------------------------------------------
# run_forward_pass: Orchestrates the layer-by-layer computation.
# Arguments:
#   Global variables implicitly used:
#     - layer_sizes: Array of neuron counts per layer.
#     - num_layers: Total number of layers.
#     - weights_storage: Buffer containing all weights contiguously.
#     - prev_layer_activations: Initial input activations (a^[0]).
#     - current_layer_activations: Buffer to store intermediate activations.
# Returns:
#   a0: Pointer to the final layer's output activations (before argmax).
#   a1: Number of neurons in the output layer.
# Modifies:
#   current_layer_activations, and potentially swaps buffer pointers for prev/current.
# Clobbers: s0-s11 (local usage, saved/restored), t0-t6, a0-a7 (arguments to called functions).
run_forward_pass:
    # Save callee-saved registers
    addi sp, sp, -48 # Space for ra, s0-s10 (12 registers * 4 bytes)
    sw ra, 0(sp)
    sw s0, 4(sp)   # current_layer_index
    sw s1, 8(sp)   # ptr_to_layer_sizes_array
    sw s2, 12(sp)  # ptr_to_weights_current_layer
    sw s3, 16(sp)  # ptr_to_prev_activations_buffer
    sw s4, 20(sp)  # ptr_to_curr_activations_buffer
    sw s5, 24(sp)  # total_num_layers
    sw s6, 28(sp)  # num_neurons_prev_layer
    sw s7, 32(sp)  # num_neurons_curr_layer
    sw s8, 36(sp)  # temp_activation_buffer_1 (address)
    sw s9, 40(sp)  # temp_activation_buffer_2 (address)
    sw s10, 44(sp) # is_output_layer_flag

    # Initialize pointers and layer counts
    la s1, layer_sizes
    lw s5, num_layers       # s5 = total_num_layers (e.g., 4 for 3 hidden + 1 output)
                            # Note: num_layers from parsing is count of entries like 4,8,15,3.
                            # This means (num_layers - 1) is the number of weight matrices/computation steps.

    la s2, weights_storage  # s2 = base pointer for weights

    # Setup initial activation buffers
    # The initial input is in `prev_layer_activations` as per parsing.
    # We need two buffers to ping-pong activations between layers.
    # Let's use `prev_layer_activations` and `current_layer_activations` from .data
    la s8, prev_layer_activations   # Buffer 1, initially holds a^[0]
    la s9, current_layer_activations # Buffer 2, will hold a^[1], then a^[3], etc.

    mv s3, s8  # s3 = prev_activations_ptr = buffer with a^[0]
    mv s4, s9  # s4 = curr_activations_ptr = buffer for a^[1]

    lw s6, 0(s1)   # s6 = num_neurons_prev_layer = layer_sizes[0] (input layer size)

    li s0, 1       # s0 = current_layer_index (starts from 1, for layer_sizes[1], weights_l1)
                   # Loop will run from layer 1 up to (total_num_layers - 1)

forward_pass_loop:
    # Loop condition: current_layer_index < total_num_layers
    bge s0, s5, forward_pass_done # If current_layer_index >= total_num_layers, all computation layers done.

    # Get number of neurons for current layer: layer_sizes[current_layer_index]
    slli t0, s0, 2 # offset = current_layer_index * 4
    add t0, s1, t0 # address of layer_sizes[current_layer_index]
    lw s7, 0(t0)   # s7 = num_neurons_curr_layer

    # Determine if this is the output layer (last computation step)
    # The last computation step is when current_layer_index == total_num_layers - 1
    li t1, 1
    sub t1, s5, t1 # t1 = total_num_layers - 1
    li s10, 0      # s10 = is_output_layer_flag = 0 (false, apply ReLU)
    beq s0, t1, set_output_layer_flag # If current_layer_index == total_num_layers - 1
    j prep_matmul_call
set_output_layer_flag:
    li s10, 1      # s10 = is_output_layer_flag = 1 (true, skip ReLU)

prep_matmul_call:
    # Arguments for matrix_vector_multiply_and_relu:
    # a0: W_ptr (s2)
    # a1: a_prev_ptr (s3)
    # a2: a_curr_ptr (s4)
    # a3: num_neurons_curr (s7)
    # a4: num_neurons_prev (s6)
    # a5: is_output_layer_flag (s10)
    mv a0, s2
    mv a1, s3
    mv a2, s4
    mv a3, s7
    mv a4, s6
    mv a5, s10
    call matrix_vector_multiply_and_relu

    # Update weights pointer for the next layer:
    # Weights for current layer were num_neurons_curr * num_neurons_prev bytes.
    mul t0, s7, s6 # num_neurons_curr * num_neurons_prev
    add s2, s2, t0 # Advance weights pointer

    # Update num_neurons_prev for the next iteration
    mv s6, s7      # Prev layer's neuron count for next iter is current layer's neuron count

    # Ping-pong activation buffers:
    # Current layer's output (in s4) becomes next iteration's previous activations.
    # The buffer that was s3 can be reused for next iteration's current output.
    mv t0, s3      # t0 = old prev_activations_ptr
    mv s3, s4      # new prev_activations_ptr = current_activations_ptr
    mv s4, t0      # new current_activations_ptr = old prev_activations_ptr (for reuse)

    addi s0, s0, 1 # current_layer_index++
    j forward_pass_loop

forward_pass_done:
    # The final activations are in the buffer pointed to by s3 (due to the last swap).
    # s6 contains the number of neurons in this final output layer.
    mv a0, s3      # Return pointer to final output activations
    mv a1, s6      # Return number of neurons in output layer

    # Restore callee-saved registers
    lw ra, 0(sp)
    lw s0, 4(sp)
    lw s1, 8(sp)
    lw s2, 12(sp)
    lw s3, 16(sp)
    lw s4, 20(sp)
    lw s5, 24(sp)
    lw s6, 28(sp)
    lw s7, 32(sp)  # Make sure this matches if s7 was saved (it was not in this version of stack frame)
                   # The stack frame was -48, for ra, s0-s10. s7 is at 32(sp).
    lw s8, 36(sp)
    lw s9, 40(sp)
    lw s10, 44(sp)
    addi sp, sp, 48

    ret

#-------------------------------------------------------------------------------
# Argmax Implementation
#-------------------------------------------------------------------------------
# argmax: Finds the index of the maximum value in a vector.
# Arguments:
#   a0: Pointer to the vector of values (output layer activations, stored as words).
#   a1: Number of elements in the vector.
# Returns:
#   a0: Index of the maximum value (0, 1, or 2, etc.).
# Clobbers: t0-t5, a0, a1 (though a1 is value, a0 becomes result)
# Registers used:
#   s0: current_ptr to vector elements
#   s1: count of elements
#   s2: current_max_value
#   s3: current_max_index
#   s4: loop_counter (i)
#   t0: current_element_value
argmax:
    # Save callee-saved registers
    addi sp, sp, -20 # Space for ra, s0-s4
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    sw s2, 12(sp)
    sw s3, 16(sp)
    # s4 is also used.
    addi sp, sp, -4
    sw s4, 20(sp) # s4 at 20(sp) from original sp

    mv s0, a0      # s0 = pointer to vector
    mv s1, a1      # s1 = number of elements

    # Initialize max_value to a very small number or the first element.
    # Let's use the first element.
    lw s2, 0(s0)   # s2 = max_value = vector[0]
                   # Values are signed 32-bit (representing 8-bit conceptual values).
                   # The problem states "sign extension before performing comparisons".
                   # lw loads a word; if stored correctly, it's fine.
                   # If it was an 8-bit value stored then loaded, sign extension needs care.
                   # Here, output activations from NN are already 32-bit signed words.
    li s3, 0       # s3 = max_index = 0

    li s4, 1       # s4 = loop_counter i, starting from the second element (index 1)

argmax_loop:
    bge s4, s1, argmax_done # if i >= num_elements, loop is done

    # Load current element vector[i]
    slli t0, s4, 2   # t0 = i * 4 (offset for word array)
    add t0, s0, t0   # t0 = address of vector[i]
    lw t0, 0(t0)     # t0 = current_element_value

    # Compare current_element_value (t0) with max_value (s2)
    # Values are signed. bgt performs signed comparison.
    ble t0, s2, argmax_next_element # if current_element_value <= max_value, continue

    # New maximum found
    mv s2, t0        # max_value = current_element_value
    mv s3, s4        # max_index = i

argmax_next_element:
    addi s4, s4, 1   # i++
    j argmax_loop

argmax_done:
    mv a0, s3        # Return max_index in a0

    # Restore callee-saved registers
    lw s4, 20(sp)
    lw s3, 16(sp)
    lw s2, 12(sp)
    lw s1, 8(sp)
    lw s0, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 24 # Adjusted for s4 save

    ret

# End of _start, other functions will be defined below.
# Syscall wrappers and other utilities will be added in subsequent steps.
# Note: Actual stack initialization might be needed depending on the execution environment (e.g. qemu -bios none).
# For now, assuming a basic environment where global/static data is primary.
# If functions use the stack extensively for local vars or saving registers, `sp` must be valid.
# Let's add a simple stack setup for robustness.
# In a typical linked program, `_stack_start` or similar would be provided by the linker script.
# We'll assume a region of memory is available for the stack.
# For qemu, often the top of available RAM is used.
# For this exercise, we'll manage data mostly in .data/.bss or registers, minimizing complex stack frames initially.
# However, `call` instructions will use the stack for `ra`.

# Minimal stack setup if needed (usually provided by linker script or environment):
# .section .stack
# .align 4 # Ensure stack is aligned (e.g., 16-byte for RV64, 4 or 8 for RV32)
# stack_mem: .space 4096 # 4KB stack
# _stack_top: # Label for the top of the stack (highest address)

# In _start, if not set by environment:
# la sp, _stack_top


#-------------------------------------------------------------------------------
# Main Program (_start)
#-------------------------------------------------------------------------------
_start:
    # Initialize stack pointer if not done by environment.
    # For qemu, it's often pre-initialized. For this exercise, we assume it's usable.
    # If functions make calls, `ra` is pushed, so `sp` needs to be valid.
    # Example: la sp, _stack_top (if _stack_top is defined)

    # --- Save s0-s11 if they are used by _start and need to be preserved for an OS ---
    # (Not strictly necessary if _start is the absolute entry and exit)
    # For simplicity, we'll use s-registers directly for clarity of main flow variables.

    # Pointers to different parts of the input string
    # s0: ptr_to_arch_line_start
    # s1: ptr_to_weights_line_start
    # s2: ptr_to_input_vector_line_start
    # s3: ptr_to_end_of_arch_line (points to the '\n')
    # s4: ptr_to_end_of_weights_line (points to the '\n')
    # s5: ptr_to_end_of_input_vector_line (points to the last char or '\n')

    # 1. Read the entire input string
    la a0, input_string_buffer
    li a1, 4096                # Max buffer size
    call read_full_input
    # a0 now contains number of bytes read. Store it if needed, e.g., in s11.
    mv s11, a0 # s11 = total_bytes_read

    # 2. Find newline characters to delineate the three input parts.
    # Find first newline: end of architecture line
    la s0, input_string_buffer # s0 = start of arch line
    mv a0, s0                  # Start searching from beginning of buffer
    li a1, '\n'                # Character to find
    mv a2, s11                 # Max length to search (total bytes read)
    call find_char
    # a0 = pointer to first '\n', a1 = 0 if found.
    # Assume valid input: newlines are present.
    mv s3, a0                  # s3 = ptr to first '\n' (end of arch line)

    # Find second newline: end of weights line
    addi s1, a0, 1             # s1 = start of weights line (char after first '\n')
    mv a0, s1                  # Start searching from start of weights line
    li a1, '\n'                # Character to find
    sub a2, s11, s1            # Max length: total_bytes - current_offset
    add a2, a2, input_string_buffer # Calculate remaining length correctly: end_of_buffer - start_of_search
    sub a2, s11, s0            # s11 is length, s0 is start of buffer.
                               # length_to_search = total_read - (current_pos - buffer_start)
    la t0, input_string_buffer
    sub t1, s1, t0             # t1 = offset of s1 from buffer_start
    sub a2, s11, t1            # a2 = total_bytes_read - offset_of_s1
    call find_char
    mv s4, a0                  # s4 = ptr to second '\n' (end of weights line)

    # Third part (input vector) starts after the second newline and goes to end of input.
    addi s2, a0, 1             # s2 = start of input vector line
    # End of input vector line (s5) is effectively input_string_buffer + total_bytes_read.
    # Or, if it might also end with a newline that was read:
    mv a0, s2
    li a1, '\n'
    la t0, input_string_buffer
    sub t1, s2, t0
    sub a2, s11, t1
    call find_char
    # If find_char returns a1=0, then s5 is a0. Otherwise, s5 is end of buffer.
    bnez a1, main_input_vec_no_trailing_newline
    mv s5, a0 # s5 = ptr to third '\n' or end of input vector line
    j main_continue_after_input_vec_end
main_input_vec_no_trailing_newline:
    la t0, input_string_buffer
    add s5, t0, s11 # s5 = end of the read input data

main_continue_after_input_vec_end:

    # 3. Parse Architecture
    # Args for parse_layer_sizes: a0=start_ptr, a1=end_ptr (points TO the newline)
    mv a0, s0      # Start of arch string
    mv a1, s3      # End of arch string (the '\n' itself)
    # s1 (global in parse_layer_sizes context) is la layer_sizes
    # num_layers (global in parse_layer_sizes context) is la num_layers
    call parse_layer_sizes
    # Return a0 is ptr after parsed segment, not used further here.

    # 4. Parse Input Vector (Initial Activations)
    # Args for parse_initial_activations: a0=start_ptr, a1=end_ptr
    mv a0, s2      # Start of input vector string
    mv a1, s5      # End of input vector string
    # s3 (global in parse_initial_activations context) is la prev_layer_activations
    call parse_initial_activations

    # 5. Parse Weights
    # Args for parse_weights: a0=start_ptr, a1=end_ptr, a2=weights_buffer_ptr
    mv a0, s1      # Start of weights string
    mv a1, s4      # End of weights string
    la a2, weights_storage
    call parse_weights

    # 6. Run Forward Pass
    # run_forward_pass uses globals, returns final_activations_ptr in a0, output_layer_size in a1.
    call run_forward_pass
    mv s0, a0      # s0 = final_activations_ptr
    mv s1, a1      # s1 = output_layer_size (number of classes)

    # 7. Run Argmax
    # Args for argmax: a0=vector_ptr, a1=num_elements
    mv a0, s0      # Pass final_activations_ptr
    mv a1, s1      # Pass output_layer_size
    call argmax
    # a0 now contains the predicted class index (0, 1, or 2)

    # 8. Convert integer result to ASCII and print
    # Result is in a0. Add '0' to convert to ASCII.
    # E.g., if a0=0, a0+'0'='0'. If a0=1, a0+'0'='1'.
    li t0, '0'
    add a0, a0, t0 # a0 is now the ASCII character '0', '1', or '2'

    # Print the character using print_char_stdout
    # print_char_stdout expects char in a0.
    call print_char_stdout

    # Optional: Print a newline character after the result for cleaner output
    # li a0, '\n'
    # call print_char_stdout

    # 9. Exit
    li a7, SYSCALL_EXIT
    ecall
