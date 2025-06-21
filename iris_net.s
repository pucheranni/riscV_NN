.data
# Buffers for input and network parameters
input_buffer: .space 32768  # 32KB buffer for the entire input string
architecture_array: .space 40 # Max 10 layers * 4 bytes/int for layer size
weights_buffer: .space 25000 # Max weights (e.g., 10 layers * 50 neurons * 50 neurons * 1 byte/weight)
activation_buffer_1: .space 128 # Max ~127 neurons per layer * 1 byte/activation (using a slightly larger power of 2)
activation_buffer_2: .space 128 # Second buffer for alternating activations

# String constants for parsing JSON
l_bracket_char: .byte '['
r_bracket_char: .byte ']'
l_curly_char: .byte '{'
r_curly_char: .byte '}'
comma_char: .byte ','
colon_char: .byte ':'
quote_char: .byte '"'
newline_char: .byte '\n'
minus_char: .byte '-'

# For printing output
newline: .string "\n" # For debugging prints if needed
output_char: .space 2 # For the final single digit output + null terminator

.text
.globl _start

# Provided syscall wrappers
# read(buffer_ptr, length) -> bytes_read
# Args: a0 = fd (0 for stdin), a1 = buffer_ptr, a2 = length
# Returns: a0 = bytes_read
read_syscall:
    li a7, 63           # syscall read (63)
    ecall
    ret

# write(buffer_ptr, length)
# Args: a0 = fd (1 for stdout), a1 = buffer_ptr, a2 = length
write_syscall:
    li a7, 64           # syscall write (64)
    ecall
    ret

# exit(status_code)
# Args: a0 = status_code
exit_syscall:
    li a7, 93           # syscall exit (93)
    ecall
    ret

# exit2(status_code) - for argmax compatibility
# Args: a1 = status_code (note: argmax uses a1 for error code)
exit2:
    mv a0, a1
    li a7, 93           # syscall exit (93)
    ecall

# =================================================================
# FUNCTION: Given a int vector, return the index of the largest
# element. If there are multiple, return the one
# with the smallest index.
# Arguments:
# a0 (int*) is the pointer to the start of the vector
# a1 (int)  is the # of elements in the vector
# Returns:
# a0 (int)  is the first index of the largest element
# Exceptions:
# - If the length of the vector is less than 1,
#   this function terminates the program with error code 77.
# Note: This version assumes elements are 8-bit signed values,
# but they are loaded as words (lw) and then sign-extended.
# =================================================================
argmax:
    # Input: a0 = pointer to vector, a1 = number of elements
    # Output: a0 = index of max element

    # Check if vector length is less than 1
    li t0, 1
    blt a1, t0, argmax_exception # If a1 < 1, then exception

    # Prologue - Save s0, s1, s2 (s2 for original a0)
    addi sp, sp, -12
    sw s0, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)

    mv s2, a0      # Save original vector pointer for index calculation later
    mv s0, zero    # max_index = 0

    # Load first element as initial max_val
    lb s1, 0(a0)   # Load byte for max_val
    slli s1, s1, 24 # Sign extend
    srai s1, s1, 24 # s1 is now sign-extended version of the first element

    mv t0, zero    # i = 0 (current_index)
    mv t2, a0      # current_element_ptr = a0

argmax_loop_start:
    beq t0, a1, argmax_loop_end # If i == num_elements, end loop

    # Load current element (t1)
    lb t1, 0(t2)   # Load byte for current element
    slli t1, t1, 24 # Sign extend
    srai t1, t1, 24 # t1 is now sign-extended current element

    # Compare current element with max_val
    # If current_element <= max_val, continue
    ble t1, s1, argmax_loop_continue

    # Else, current_element > max_val, update max_val and max_index
    mv s1, t1      # max_val = current_element
    mv s0, t0      # max_index = i

argmax_loop_continue:
    addi t0, t0, 1 # i++
    addi t2, t2, 1 # Increment element pointer (byte addressing)
    j argmax_loop_start

argmax_loop_end:
    mv a0, s0      # Return max_index

    # Epilogue
    lw s0, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    addi sp, sp, 12
    ret

argmax_exception:
    li a1, 77      # Error code for vector length < 1
    j exit2        # Terminate (using exit2 as per original argmax stub)

_start:
    # Setup stack frame (optional for _start if no complex calls before main logic)
    # addi sp, sp, -16
    # sw ra, 0(sp)
    # sw s0, 4(sp)
    # ...

    # For now, just a placeholder to read input
    # Later, this will call parsing functions and the forward pass

    # Example: Read up to 32KB into input_buffer
    li a0, 0             # stdin
    la a1, input_buffer
    li a2, 32768
    call read_syscall
    # a0 now contains bytes_read or -1 on error

    # Save callee-saved registers that will be used
    addi sp, sp, -20
    sw ra, 0(sp)
    sw s0, 4(sp)  # Will store pointer to architecture string
    sw s1, 8(sp)  # Will store pointer to weights JSON string
    sw s2, 12(sp) # Will store pointer to input vector string
    sw s3, 16(sp) # Stores end of input buffer or bytes_read

    # Read the entire input into input_buffer
    li a0, 0             # stdin
    la a1, input_buffer
    li a2, 32768         # Max buffer size
    call read_syscall    # a0 returns bytes_read or -1 on error

    # Check for read error (a0 < 0) or no input (a0 == 0)
    bltz a0, read_error_or_empty
    beqz a0, read_error_or_empty # Changed beqzx to beqz

    la s0, input_buffer      # s0 points to the start of architecture string
    add s3, s0, a0           # s3 points to the end of the read content

    # Find the first newline character to locate end of arch string / start of weights string
    mv a0, s0                # Start searching from the beginning of the buffer
    la t0, newline_char
    lb t1, 0(t0)             # Load '\n' into t1
find_first_newline:
    lb t2, 0(a0)             # Load current character
    beq t2, t1, found_first_newline # If char == '\n', found
    beq a0, s3, input_format_error  # If reached end of buffer without newline, error
    addi a0, a0, 1           # Move to next char
    j find_first_newline

found_first_newline:
    sb zero, 0(a0)           # Null-terminate the architecture string
    addi s1, a0, 1           # s1 points to the start of weights JSON string (char after '\n')

    # Find the second newline character to locate end of weights string / start of input vector string
    mv a0, s1                # Start searching from the beginning of weights string
    # t1 still holds '\n'
find_second_newline:
    lb t2, 0(a0)             # Load current character
    beq t2, t1, found_second_newline # If char == '\n', found
    beq a0, s3, input_format_error   # If reached end of buffer without newline, error
    addi a0, a0, 1           # Move to next char
    j find_second_newline

found_second_newline:
    sb zero, 0(a0)           # Null-terminate the weights JSON string
    addi s2, a0, 1           # s2 points to the start of input vector string (char after '\n')

    # The input vector string is assumed to go to the end of the read input or next newline (if any)
    # For simplicity, we'll assume it's the last part and null-terminate it at s3 if not already newline
    # This might need adjustment if the input guarantees a final newline.
    # For now, let's assume the third part is terminated by the end of read data.
    # If s3 is not already pointing to a null or newline from the read, ensure null termination for the input vector.
    # This is implicitly handled if the input always ends with a newline. If not, the last part might not be null-terminated
    # by the above logic if it's the very end of the file.
    # The `bytes_read` in `a0` from `read_syscall` can be used to null-terminate the last segment.
    # `s3` points to `input_buffer + bytes_read`.
    # We can place a null terminator there if the last character wasn't a newline.
    addi t0, s3, -1 # Last character read
    lb t1, 0(t0)    # load it
    la t2, newline_char
    lb t2, 0(t2)    # load '\n'
    bne t1, t2, null_terminate_last_segment # if last char is not newline
    j proceed_to_parsing # it was newline, so it's fine
null_terminate_last_segment:
    sb zero, 0(s3) # Null terminate the whole buffer at the end of read content.
                   # This ensures the last segment (input vector) is null-terminated.

proceed_to_parsing:
    # Pointers are set:
    # s0: architecture string
    # s1: weights JSON string
    # s2: input vector string
    # s3: end of read input

    # Additional saved registers for main logic:
    # s4: num_layers
    # s5: pointer to current activation buffer (alternates between buffer_1 and buffer_2)
    # s6: pointer to final output logits (from forward_pass)
    # s7: number of output neurons (for argmax)

    # Save more s-registers if they are used by parsing and forward_pass and need to persist across them in _start
    # The current stack allocation is -20 (ra, s0, s1, s2, s3). Need more if s4-s7 are to be kept on stack.
    # Let's adjust stack for s0-s7 + ra = 9 registers * 4 bytes = 36 bytes. Round to 40 for alignment.
    # This was done by changing -20 to -40 and adjusting offsets.
    # The original was:
    # addi sp, sp, -20
    # sw ra, 0(sp)
    # sw s0, 4(sp)
    # sw s1, 8(sp)
    # sw s2, 12(sp)
    # sw s3, 16(sp)
    # Let's assume for now that s4-s7 are managed within _start or returned/passed via a0.
    # The current parsing functions use their own s-registers locally by saving/restoring.

    # Call parse_architecture
    mv a0, s0                  # a0 = pointer to architecture string
    call parse_architecture
    mv s4, a0                  # s4 = num_layers (returned by parse_architecture)
                               # architecture_array is now populated.

    # Call parse_weights
    mv a0, s1                  # a0 = pointer to weights JSON string
    la a1, architecture_array  # a1 = pointer to architecture_array (context, not directly used by current parse_weights)
    mv a2, s4                  # a2 = num_layers
    la a3, weights_buffer      # a3 = pointer to destination weights_buffer
    call parse_weights
                               # weights_buffer is now populated. a0 from parse_weights is end ptr, not stored for now.

    # Call parse_input_vector
    mv a0, s2                  # a0 = pointer to input vector string
    la a1, activation_buffer_1 # a1 = pointer to destination (first activation buffer)
    call parse_input_vector
                               # activation_buffer_1 is now populated with initial inputs.
                               # a0 from parse_input_vector is num inputs parsed, not stored for now.
    la s5, activation_buffer_1 # s5 points to the initial activation buffer (populated by parse_input_vector)

    # Call forward_pass
    la a0, architecture_array
    mv a1, s4                  # num_layers (from s4)
    la a2, weights_buffer
    mv a3, s5                  # initial_activations_ptr (e.g., activation_buffer_1)
    la a4, activation_buffer_2 # Pointer to the other buffer for ping-ponging
    call forward_pass
    mv s6, a0                  # s6 now points to the buffer with final output logits

    # Argmax
    # a0 needs pointer to final logits (s6)
    # a1 needs number of elements in the output layer.
    # Output layer size is architecture_array[num_layers-1].
    # num_layers is in s4. Index of last layer size in arch_array is s4 - 1.
    mv a0, s6                  # Pointer to the final output logits

    addi t0, s4, -1            # t0 = last layer index in architecture_array (num_layers - 1)
    slli t0, t0, 2             # t0 = byte offset for this index (each entry is 4 bytes)
    la t1, architecture_array
    add t1, t1, t0             # t1 now points to architecture_array[num_layers-1]
    lw a1, 0(t1)               # a1 = number of neurons in the output layer

    call argmax
                               # Result of argmax (index 0, 1, or 2) is in a0.

    # Convert integer result from argmax to ASCII and print
    addi a0, a0, '0'           # Convert digit (0,1,2) to ASCII ('0','1','2')
    la a1, output_char
    sb a0, 0(a1)
    li a0, 1
    la a1, output_char
    li a2, 1
    call write_syscall

    # Restore callee-saved registers and return from _start (or exit)
    lw ra, 0(sp)
    lw s0, 4(sp)
    lw s1, 8(sp)
    lw s2, 12(sp)
    lw s3, 16(sp)
    addi sp, sp, 20

    li a0, 0 # Exit success
    call exit_syscall

read_error_or_empty:
    # Handle read error or empty input
    li a0, 1 # Error code for read error
    call exit_syscall

input_format_error:
    # Handle missing newlines (input format error)
    li a0, 2 # Error code for input format error
    call exit_syscall

# Utility functions

# =================================================================
# FUNCTION: find_char
# Description: Searches for a character in a null-terminated string.
# Arguments:
#   a0 (char*): Pointer to the start of the string.
#   a1 (char): The character to find.
# Returns:
#   a0 (char*): Pointer to the first occurrence of the character,
#               or pointer to the null terminator if not found.
# Registers used: t0, t1 (temporaries)
# =================================================================
find_char:
    # a0 = current_ptr, a1 = char_to_find
find_char_loop:
    lb t0, 0(a0)      # Load byte from current_ptr
    beq t0, zero, find_char_not_found # If null terminator, char not found
    beq t0, a1, find_char_found     # If char matches, found
    addi a0, a0, 1    # Increment current_ptr
    j find_char_loop

find_char_found:
    ret # a0 points to the character
find_char_not_found:
    ret # a0 points to the null terminator

# =================================================================
# FUNCTION: parse_int_from_string
# Description: Parses an integer from a string. Stops at the first non-digit
#              (after potential sign). Handles negative numbers.
# Arguments:
#   a0 (char*): Pointer to the string containing the number.
# Returns:
#   a0 (int): The parsed integer.
#   a1 (char*): Pointer to the character immediately following the parsed number.
# Registers used: t0-t5 (temporaries)
# Assumes result fits in a 32-bit signed integer.
# =================================================================
parse_int_from_string:
    # Prologue not strictly necessary if we manage t-registers carefully
    # or if called functions are simple enough.
    # For robustness in general functions, save/restore would be good.
    # Here, we document t-register usage.

    mv t0, a0          # t0 = current char pointer
    li t1, 0           # t1 = result (parsed integer)
    li t2, 1           # t2 = sign (1 for positive, -1 for negative)
    li t3, 0           # t3 = flag, 1 if at least one digit found

    # Check for sign
    lb t4, 0(t0)       # Load first character
    la t5, minus_char
    lb t5, 0(t5)
    bne t4, t5, parse_int_skip_sign # If not '-', skip sign processing
    li t2, -1          # Set sign to negative
    addi t0, t0, 1     # Move past '-'

parse_int_skip_sign:
    # Loop to parse digits
parse_int_loop:
    lb t4, 0(t0)       # Load current character
    li t5, '0'
    blt t4, t5, parse_int_done # If char < '0', done
    li t5, '9'
    bgt t4, t5, parse_int_done # If char > '9', done

    # It's a digit
    li t3, 1           # Mark that a digit was found
    li t5, '0'
    sub t4, t4, t5     # Convert ASCII digit to integer value (t4 = t4 - '0')

    # Accumulate result: result = result * 10 + digit
    li t5, 10
    mul t1, t1, t5     # result = result * 10
    add t1, t1, t4     # result = result + digit

    addi t0, t0, 1     # Move to next character
    j parse_int_loop

parse_int_done:
    # Check if any digit was parsed
    beq t3, zero, parse_int_error # If no digits found after sign (or at all), it's an error

    # Apply sign
    mv t3, t1          # Use t3 as a temp for multiplication if needed
                       # but direct mul with t1 should be fine.
    mul t1, t1, t2     # result = result * sign

    mv a0, t1          # Return parsed integer in a0
    mv a1, t0          # Return pointer to next char in a1
    ret

parse_int_error: # Should not happen if input is well-formed and we skip non-digits before calling
    # For now, if no digits are found, return 0 and original pointer.
    # Or, set an error flag / use an error exit.
    # Given the problem constraints, assume valid numbers where expected.
    # For robustness, one might want to handle this more gracefully.
    # For this problem, we expect valid numbers.
    # If called on "abc", it would return 0 and pointer to 'a'.
    # If called on "-abc", it would return 0 and pointer to 'a'.
    # If called on ",", it would return 0 and pointer to ','.
    # This behavior is acceptable if we manage the calling context.
    mv a1, a0          # Reset a1 to original pointer
    li a0, 0           # Return 0
    ret

# =================================================================
# FUNCTION: parse_architecture
# Description: Parses the architecture string (e.g., "4,8,15,3")
#              and populates architecture_array.
# Arguments:
#   a0 (char*): Pointer to the architecture string.
# Returns:
#   a0 (int): Number of layers parsed. architecture_array is populated.
# Registers used: s4 (num_layers), s5 (current_arch_ptr), s6 (temp_char_ptr)
#                 a0, a1 from parse_int_from_string
#                 t0-t5 from parse_int_from_string and locally
# =================================================================
parse_architecture:
    addi sp, sp, -12
    sw s4, 0(sp)    # num_layers
    sw s5, 4(sp)    # current_string_ptr
    sw s6, 8(sp)    # arch_array_write_ptr

    mv s5, a0             # s5 = current position in architecture string
    la s6, architecture_array # s6 = pointer to write into architecture_array
    li s4, 0              # s4 = num_layers = 0

parse_arch_loop:
    # Skip leading non-digits (e.g., spaces if any, though not expected by problem spec)
    # For this problem, assume numbers start immediately or after a comma.

    mv a0, s5             # Argument for parse_int_from_string
    call parse_int_from_string
    # a0 = parsed integer, a1 = pointer to char after integer

    sw a0, 0(s6)          # Store parsed layer size into architecture_array
    addi s6, s6, 4        # Move architecture_array pointer to next slot
    addi s4, s4, 1        # Increment num_layers

    mv s5, a1             # Update current position in string to char after integer

    # Check for end of string or next character (should be comma or null)
    lb t0, 0(s5)
    beq t0, zero, parse_arch_done # End of string

    la t1, comma_char
    lb t1, 0(t1)
    beq t0, t1, parse_arch_next_num # If comma, expect another number

    # If not comma and not null, it's an unexpected format.
    # For now, assume valid format and treat as done if not comma.
    # Or, this could be an error. Let's assume it means done for simplicity.
    j parse_arch_done

parse_arch_next_num:
    addi s5, s5, 1        # Skip the comma
    j parse_arch_loop

parse_arch_done:
    mv a0, s4             # Return num_layers in a0

    lw s4, 0(sp)
    lw s5, 4(sp)
    lw s6, 8(sp)
    addi sp, sp, 12
    ret

# =================================================================
# FUNCTION: parse_input_vector
# Description: Parses the input vector string (e.g., "59,30,51,18")
#              and populates activation_buffer_1 with 8-bit signed integers.
# Arguments:
#   a0 (char*): Pointer to the input vector string.
#   a1 (char*): Pointer to the destination buffer (e.g., activation_buffer_1).
# Returns:
#   a0 (int): Number of input values parsed.
# Registers used: s4 (num_inputs), s5 (current_string_ptr), s6 (dest_buffer_ptr)
#                 a0, a1 from parse_int_from_string
#                 t0-t5 from parse_int_from_string and locally
# =================================================================
parse_input_vector:
    addi sp, sp, -12
    sw s4, 0(sp)    # num_inputs
    sw s5, 4(sp)    # current_string_ptr
    sw s6, 8(sp)    # dest_buffer_ptr

    mv s5, a0             # s5 = current position in input vector string
    mv s6, a1             # s6 = pointer to write into destination buffer
    li s4, 0              # s4 = num_inputs = 0

parse_input_vec_loop:
    mv a0, s5             # Argument for parse_int_from_string
    call parse_int_from_string
    # a0 = parsed integer, a1 = pointer to char after integer

    # Clamp the parsed integer to 8-bit signed range before storing
    # a0 holds the parsed integer. Call clamp_to_signed_8bit.
    call clamp_to_signed_8bit # a0 is modified in-place to be the clamped value.
    # The problem says "Four comma-separated integers ... treated as 8-bit signed integers".
    # This ensures they are stored as such.
    sb a0, 0(s6)          # Store clamped value (lower 8 bits) into buffer
    addi s6, s6, 1        # Move buffer pointer to next byte
    addi s4, s4, 1        # Increment num_inputs

    mv s5, a1             # Update current position in string

    # Check for end of string or next character
    lb t0, 0(s5)
    beq t0, zero, parse_input_vec_done

    la t1, comma_char
    lb t1, 0(t1)
    beq t0, t1, parse_input_vec_next_num

    j parse_input_vec_done

parse_input_vec_next_num:
    addi s5, s5, 1        # Skip the comma
    j parse_input_vec_loop

parse_input_vec_done:
    mv a0, s4             # Return num_inputs in a0

    lw s4, 0(sp)
    lw s5, 4(sp)
    lw s6, 8(sp)
    addi sp, sp, 12
    ret

# =================================================================
# FUNCTION: parse_weights
# Description: Parses the JSON weights string and populates weights_buffer.
# Arguments:
#   a0 (char*): Pointer to the JSON weights string.
#   a1 (int*): Pointer to architecture_array. (Not directly used here, but useful for context)
#   a2 (int): Number of layers. (Used to know how many "lx" to look for)
#   a3 (char*): Pointer to the destination weights_buffer.
# Returns:
#   a0 (char*): Pointer to the current position in weights_buffer after parsing.
# Registers used: Too many to list concisely, heavy use of s-registers for state.
# This is a simplified JSON parser, expecting a very specific format.
# {"l1":[[w,w],[w,w]],"l2":[[w,w],[w,w]],...}
# =================================================================
parse_weights:
    # s0: current_json_ptr
    # s1: current_weights_buffer_ptr
    # s2: layer_counter (1 to num_layers-1, as layer 0 is input)
    # s3: num_total_layers (from argument a2)
    # s4: char being searched for ([, ], ,, ", l, 1, 2, etc.)
    # s5, s6, s7: temps for characters, pointers
    # t0-t5: general temps, and for parse_int_from_string

    addi sp, sp, -32
    sw ra, 0(sp)
    sw s0, 4(sp)  # current_json_ptr
    sw s1, 8(sp)  # current_weights_buffer_ptr
    sw s2, 12(sp) # layer_index (0 for l1, 1 for l2, etc.)
    sw s3, 16(sp) # num_matrix_layers (num_total_layers - 1)
    sw s4, 20(sp) # char_to_find / temp char
    sw s5, 24(sp) # temp storage
    sw s6, 28(sp) # temp storage


    mv s0, a0      # current_json_ptr
    mv s1, a3      # current_weights_buffer_ptr (destination)
    li s2, 0       # layer_index, starts at 0 for "l1"
    addi s3, a2, -1 # Number of weight matrices to parse (num_total_layers - 1)

parse_weights_outer_loop: # Loop for each layer "l1", "l2", ...
    beq s2, s3, parse_weights_all_done # If layer_index == num_matrix_layers, we are done

    # Find "lx": (e.g., "l1", "l2")
    # Expects format like: ... ,"l1":[[...
    # Skip to the quote identifying the layer label
    la t0, quote_char
    lb s4, 0(t0)          # s4 = '"'
    mv a0, s0             # search from current_json_ptr
    mv a1, s4             # find '"'
    call find_char
    mv s0, a0             # s0 now points to '"'
    addi s0, s0, 1        # Move past '"'

    # Check if it's 'l'
    lb t0, 0(s0)
    li t1, 'l'
    bne t0, t1, json_format_error # Expected 'l'

    addi s0, s0, 1 # Move past 'l'
    # Check for digit (layer number part)
    # We don't strictly need to parse the digit if we assume "l1", "l2" appear in order.
    # We just need to find the colon after the layer name.
    # Let's assume they are in order and just find ":" after "lx"

    # Skip until colon ':'
    la t0, colon_char
    lb s4, 0(t0)          # s4 = ':'
    mv a0, s0             # search from current_json_ptr (after "l" and digit)
    mv a1, s4             # find ':'
    call find_char
    mv s0, a0             # s0 now points to ':'
    addi s0, s0, 1        # Move past ':'

    # Now we expect the start of the 2D array: [[
    # Find first '['
    la t0, l_bracket_char
    lb s4, 0(t0)          # s4 = '['
    mv a0, s0
    mv a1, s4
    call find_char
    mv s0, a0             # s0 points to first '['
    addi s0, s0, 1        # Move past first '['

    # Inner loop for rows of the matrix (each row is a list of weights for one neuron)
parse_weights_row_loop:
    # s0 points after the layer's main "[[", or after a "]," that ended the previous row.
    # We need to find the next '[' (start of a new row) or ']' (end of the layer's matrix).
    # The find_char call below handles this by searching for '['. If ']' is encountered first
    # by find_char scanning for '[', find_char would stop at ']' if '[' is not found before it,
    # or if ']' is the character it's looking for (which is not the case here).
    # A better approach for find_char would be to make it stop at any of a set of chars,
    # but with the current find_char, we search for '['.

    # Find '[' for the current row.
    # find_char(s0, '[') will update a0 to point to the found '['.
    # If ']' or null is encountered before '[', a0 will point to that.
    la t0, l_bracket_char
    lb s4, 0(t0)          # s4 = '['
    mv a0, s0
    mv a1, s4
    call find_char

    # Check if we found '[' or ']' (end of matrix for layer)
    lb t1, 0(a0) # char found by find_char
    la t2, r_bracket_char
    lb t2, 0(t2)
    beq t1, t2, found_layer_end_pw # If ']' is found before '[', means end of this layer's matrix

    mv s0, a0             # s0 points to '[' of the current row
    addi s0, s0, 1        # Move past '[' of the current row

    # Innermost loop for values (weights) in the current row
parse_weights_value_loop:
    # Skip non-digits/non-minus signs (e.g. spaces)
    # This simple parser assumes numbers are next.
skip_non_val_chars_pw:
    lb t0, 0(s0)
    beq t0, zero, json_format_error # Unexpected end
    la t1, r_bracket_char
    lb t1, 0(t1)
    beq t0, t1, found_row_end_pw # Found ']' ending the current row

    # Check for comma, skip if present (between numbers)
    la t1, comma_char
    lb t1, 0(t1)
    beq t0, t1, is_val_comma_pw

    # If not ']' or ',', assume it's start of a number
    mv a0, s0             # Arg for parse_int_from_string
    call parse_int_from_string
    # a0 = parsed integer (weight)
    # a1 = pointer to char after integer (new s0)

    # Clamp and store the weight
    mv s5, a0 # Save parsed int before calling clamp (a0 is its input)
    call clamp_to_signed_8bit # a0 = clamped value
    sb a0, 0(s1)          # Store clamped weight into weights_buffer
    addi s1, s1, 1        # Increment weights_buffer_ptr

    mv s0, a1             # Update json_ptr to char after parsed number

    j parse_weights_value_loop # Look for next value or ']'

is_val_comma_pw:
    addi s0, s0, 1 # Skip comma
    j skip_non_val_chars_pw # Continue skipping or find next value

found_row_end_pw: # Found ']' for the current row
    addi s0, s0, 1        # Move past ']' of the row
    # Now we need to check if there's another row (starts with ',[') or end of matrix (starts with ']')
    # Check for comma separating rows, or ']' ending the matrix
    # Skip spaces until next significant char
skip_to_next_row_or_layer_end_pw:
    lb t0, 0(s0)
    beq t0, zero, json_format_error
    la t1, comma_char
    lb t1, 0(t1)
    beq t0, t1, prep_next_row_pw # Found comma, expect another row '['
    la t1, r_bracket_char
    lb t1, 0(t1)
    beq t0, t1, found_layer_end_pw # Found ']', end of this layer's matrix

    # If not comma or ']', it could be whitespace. For this parser, assume no whitespace.
    # Or, it's an error.
    addi s0, s0, 1 # Skip char (e.g. whitespace if any)
    j skip_to_next_row_or_layer_end_pw

prep_next_row_pw:
    addi s0, s0, 1 # Skip comma
    # We should be at the start of the next row, which begins with '['
    # The beginning of parse_weights_row_loop expects to find this '['
    j parse_weights_row_loop

found_layer_end_pw: # Found ']' for the current layer's matrix
    addi s0, s0, 1        # Move past ']' of the layer's matrix
    # This layer is done. Increment layer_index and go to outer loop.
    addi s2, s2, 1        # Increment layer_index
    j parse_weights_outer_loop

parse_weights_all_done:
    mv a0, s1             # Return final weights_buffer_ptr

    lw ra, 0(sp)
    lw s0, 4(sp)
    lw s1, 8(sp)
    lw s2, 12(sp)
    lw s3, 16(sp)
    lw s4, 20(sp)
    lw s5, 24(sp)
    lw s6, 28(sp)
    addi sp, sp, 32
    ret

json_format_error:
    # Print 'E' for JSON error then exit
    li t5, 'E' # Using t5 as a0 will be clobbered by syscall
    la a1, output_char
    sb t5, 0(a1)
    li a0, 1            # stdout
    # a1 already has output_char pointer
    li a2, 1            # length
    call write_syscall  # Print 'E'

    li a0, 3 # Error code for JSON format error
    call exit_syscall

input_format_error:
    # Print 'F' for input format error then exit
    li t5, 'F'
    la a1, output_char
    sb t5, 0(a1)
    li a0, 1
    la a1, output_char
    li a2, 1
    call write_syscall # Print 'F'

    li a0, 2 # Error code for input format error
    call exit_syscall

read_error_or_empty:
    # Print 'R' for read error then exit
    li t5, 'R'
    la a1, output_char
    sb t5, 0(a1)
    li a0, 1
    la a1, output_char
    li a2, 1
    call write_syscall # Print 'R'

    li a0, 1 # Error code for read error
    call exit_syscall

argmax_exception:
    # Print 'A' for argmax error then exit
    li t5, 'A'
    la a1, output_char
    sb t5, 0(a1)
    li a0, 1
    la a1, output_char
    li a2, 1
    call write_syscall # Print 'A'

    li a1, 77      # Error code for vector length < 1
    j exit2        # Terminate (using exit2 as per original argmax stub)


# Helper function to skip spaces (if needed, not strictly used by current logic)
skip_whitespace:
    # a0: current pointer
    # returns a0: pointer after whitespace
skip_whitespace_loop:
    lb t0, 0(a0)
    beq t0, zero, skip_whitespace_done # end of string
    li t1, ' '
    beq t0, t1, skip_whitespace_skip
    li t1, '\t'
    beq t0, t1, skip_whitespace_skip
    li t1, '\n' # Though newlines are separators in our top-level input
    beq t0, t1, skip_whitespace_skip
    li t1, '\r'
    beq t0, t1, skip_whitespace_skip
    j skip_whitespace_done # Not a whitespace char
skip_whitespace_skip:
    addi a0, a0, 1
    j skip_whitespace_loop
skip_whitespace_done:
    ret

sign_extend_byte:
    # Input: a0 = value whose lower 8 bits are to be sign-extended
    # Output: a0 = sign-extended value
    slli a0, a0, 24
    srai a0, a0, 24
    ret

clamp_to_signed_8bit:
    # Input: a0 = value to clamp
    # Output: a0 = clamped value (-127 to 127)
    # Uses t0, t1
    li t0, 127
    li t1, -127 # Corrected: was -128, but problem states -127 to 127 for values
                # However, weight matrices in example show -128.
                # Let's stick to -128 to 127 for 8-bit signed range.
    li t1, -128 # Re-correcting: standard 8-bit signed is -128 to 127.
                # The prompt says "8-bit signed integers (-127 to 127)" but then "slli t0, t0, 24; srai t0, t0, 24"
                # implies standard 8-bit behavior. The example weights also include -128.
                # I will assume standard 8-bit range: -128 to 127.

    bgt a0, t0, clamp_upper # if a0 > 127, clamp to 127
    blt a0, t1, clamp_lower # if a0 < -128, clamp to -128
    j clamp_done
clamp_upper:
    mv a0, t0
    j clamp_done
clamp_lower:
    mv a0, t1
clamp_done:
    ret

# =================================================================
# FUNCTION: forward_pass
# Description: Performs the forward pass of the neural network.
# Arguments:
#   a0 (int*): Pointer to architecture_array
#   a1 (int): num_layers
#   a2 (char*): Pointer to weights_buffer
#   a3 (char*): Pointer to initial activation buffer (input_activations_ptr)
#   a4 (char*): Pointer to the other activation buffer (output_activations_ptr for first iteration)
# Returns:
#   a0 (char*): Pointer to the buffer containing the final output logits.
# Registers (Callee-saved used):
#   s0: current_layer_idx (loop variable for layers, 0 to num_matrix_layers-1)
#   s1: num_matrix_layers (total_layers - 1)
#   s2: architecture_array_ptr (a0)
#   s3: current_weights_ptr (advances through a2)
#   s4: input_activations_ptr (alternates between a3 and a4)
#   s5: output_activations_ptr (alternates between a4 and a3)
#   s6: neurons_curr_layer
#   s7: neurons_prev_layer
#   s8: j (loop variable for current layer neurons)
#   s9: k (loop variable for previous layer neurons)
#   s10: sum_z (accumulator for Z_j^[c])
#   s11: temp_val (for individual weight or activation)
# =================================================================
forward_pass:
    addi sp, sp, -48 # Save ra, s0-s11 (1+12 = 13 regs, need 12*4 + 4 = 52. Use 48 for now, check usage)
                     # ra, s0-s10 are 12 regs = 48 bytes. s11 can be a t-reg or ensure it's saved if needed.
                     # Let's use s0-s10. That's 11 registers. 11*4 = 44. Add ra (4) = 48.
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    sw s2, 12(sp)
    sw s3, 16(sp)
    sw s4, 20(sp)
    sw s5, 24(sp)
    sw s6, 28(sp)
    sw s7, 32(sp)
    sw s8, 36(sp)
    sw s9, 40(sp)
    sw s10, 44(sp)

    mv s2, a0      # s2 = architecture_array_ptr
    mv s1, a1      # s1 = num_total_layers
    addi s1, s1, -1 # s1 = num_matrix_layers (number of weight matrices/computation layers)
    mv s3, a2      # s3 = current_weights_ptr
    mv s4, a3      # s4 = input_activations_ptr (starts with initial input)
    mv s5, a4      # s5 = output_activations_ptr (buffer for results of first layer computation)

    li s0, 0       # s0 = current_matrix_layer_idx (from 0 to num_matrix_layers - 1)
                   # This corresponds to "l1", "l2", etc. So layer "l(s0+1)"

forward_pass_layer_loop: # Loop over layers (l1, l2, ..., up to output layer)
    beq s0, s1, forward_pass_all_layers_done # If current_matrix_layer_idx == num_matrix_layers, exit loop

    # Get dimensions: neurons_prev_layer, neurons_curr_layer
    # prev_layer_arch_idx = s0
    # curr_layer_arch_idx = s0 + 1
    slli t0, s0, 2          # t0 = offset for prev_layer_arch_idx (s0 * 4)
    add t1, s2, t0          # t1 = address of architecture_array[s0]
    lw s7, 0(t1)            # s7 = neurons_prev_layer = architecture_array[s0]

    addi t0, s0, 1          # t0 = curr_layer_arch_idx (s0 + 1)
    slli t0, t0, 2          # t0 = offset for curr_layer_arch_idx
    add t1, s2, t0          # t1 = address of architecture_array[s0+1]
    lw s6, 0(t1)            # s6 = neurons_curr_layer = architecture_array[s0+1]

    li s8, 0                # s8 = j = 0 (neuron index in current layer)
forward_pass_curr_neuron_loop: # Loop over neurons 'j' in the current layer
    beq s8, s6, forward_pass_layer_done # If j == neurons_curr_layer, this layer's computation is done

    li s10, 0               # s10 = sum_z = 0 (accumulator for Z_j^[c])
    li s9, 0                # s9 = k = 0 (neuron index in previous layer / feature index)
                            # Also used as offset into input_activations_ptr for A_k
                            # And offset into weights for W_jk (relative to start of row j's weights)
forward_pass_prev_neuron_loop: # Loop over neurons 'k' in the previous layer (dot product)
    beq s9, s7, forward_pass_dot_product_done # If k == neurons_prev_layer, dot product for Z_j is complete

    # Load weight W_jk
    # Weights for current neuron j, from prev neuron k.
    # s3 already points to the start of W_j0 for current j when k=0.
    # For subsequent k, weights are contiguous.
    lb t0, 0(s3)            # t0 = W_jk (8-bit signed)
    call sign_extend_byte_reg_t0 # t0 is now sign-extended W_jk (input a0=t0, output a0=t0)
    mv t2, t0               # t2 = sign-extended W_jk

    # Load activation a_k from previous layer
    add t1, s4, s9          # t1 = address of A_prev[k] (s4 = input_activations_ptr, s9 = k)
    lb t0, 0(t1)            # t0 = a_k (8-bit signed)
    call sign_extend_byte_reg_t0 # t0 is now sign-extended a_k
    mv t3, t0               # t3 = sign-extended a_k

    # Calculate term = W_jk * a_k
    mul t4, t2, t3          # t4 = product (can be > 8-bit range)

    # Clamp term to 8-bit signed range
    mv a0, t4
    call clamp_to_signed_8bit # a0 = clamped term
    mv t4, a0               # t4 = clamped term

    # Add to sum: sum_z = sum_z + term
    add s10, s10, t4        # s10 = sum_z

    # Clamp sum_z to 8-bit signed range
    mv a0, s10
    call clamp_to_signed_8bit # a0 = clamped sum_z
    mv s10, a0              # s10 = clamped sum_z

    addi s3, s3, 1          # Advance weights_ptr to next weight W_j(k+1)
    addi s9, s9, 1          # k++
    j forward_pass_prev_neuron_loop
forward_pass_dot_product_done:
    # s10 now holds the final Z_j^[c] for neuron j of current layer

    # Check if this is the output layer
    # Output layer is when s0 (current_matrix_layer_idx) == s1 - 1 (num_matrix_layers - 1)
    addi t0, s1, -1         # t0 = index of the matrix layer leading to the output layer
    beq s0, t0, is_output_layer

    # Not output layer: Apply ReLU: A_curr[j] = max(0, Z_j^[c])
    # s10 = Z_j^[c]. Need to sign-extend it for comparison with 0.
    # (clamping already ensures it's 8-bit, but comparison needs 32-bit sign)
    mv t1, s10
    # slli t1, t1, 24 # Not needed if clamp_to_signed_8bit ensures it's correctly signed in lower 8 bits
    # srai t1, t1, 24 # and we compare properly.
    # A direct comparison with 0 should work if t1 is properly sign-extended by clamp.
    # Let's re-verify clamp_to_signed_8bit. It does return a 32b signed value.
    # So, if s10 (Z_j) is negative (e.g. -5, which is 0xFB as byte, 0xFFFFFFFB as word),
    # bltz s10, value_is_negative will work.

    bltz s10, relu_result_zero # If Z_j < 0, ReLU output is 0
    mv t2, s10              # Else, ReLU output is Z_j
    j relu_done
relu_result_zero:
    li t2, 0
relu_done:
    # Store result t2 into output_activations_ptr for current neuron j
    add t1, s5, s8          # t1 = address for A_curr[j] (s5=output_activations_ptr, s8=j)
    sb t2, 0(t1)            # Store ReLU result (or Z_j if output layer)
    j after_activation_storage

is_output_layer:
    # It IS the output layer: A_curr[j] = Z_j^[c] (no ReLU)
    add t1, s5, s8          # t1 = address for A_curr[j]
    sb s10, 0(t1)           # Store Z_j directly

after_activation_storage:
    # s3 (weights_ptr) has advanced by neurons_prev_layer (s7) for neuron j.
    # It should be correct for the start of the next neuron j+1's weights.
    # No, s3 was advanced inside the k loop. It's already at the start of weights for j+1.

    addi s8, s8, 1          # j++
    j forward_pass_curr_neuron_loop
forward_pass_layer_done:
    # Current layer's computations are complete. Results are in s5 (output_activations_ptr).
    # This buffer now becomes the input for the next layer.
    # Ping-pong buffers:
    mv t0, s4               # t0 = old input_activations_ptr
    mv s4, s5               # New input_activations_ptr is the old output_activations_ptr
    mv s5, t0               # New output_activations_ptr is the old input_activations_ptr

    addi s0, s0, 1          # current_matrix_layer_idx++
    j forward_pass_layer_loop

forward_pass_all_layers_done:
    # All layers processed. The final activations (logits for output layer)
    # are in s4 (because of the last swap).
    mv a0, s4               # Return pointer to the final output buffer

    lw ra, 0(sp)
    lw s0, 4(sp)
    lw s1, 8(sp)
    lw s2, 12(sp)
    lw s3, 16(sp)
    lw s4, 20(sp)
    lw s5, 24(sp)
    lw s6, 28(sp)
    lw s7, 32(sp)
    lw s8, 36(sp)
    lw s9, 40(sp)
    lw s10, 44(sp)
    addi sp, sp, 48
    ret

# Helper for forward_pass to call sign_extend_byte on t0
# This is because `call` might clobber a0 if sign_extend_byte uses it.
# sign_extend_byte takes a0 and returns a0.
sign_extend_byte_reg_t0:
    mv a0, t0
    call sign_extend_byte # Modifies a0
    mv t0, a0
    ret


# End of program
