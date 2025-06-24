# RISC-V 32IM Assembly for IrisNet Inference
#
# Author: Gemini
# Date: 2024-05-21
#
# Description:
# This program performs a forward pass for a pre-trained neural network (IrisNet)
# to classify Iris flowers. It reads the network architecture, weights, and an
# input vector from a single string, performs all calculations using 8-bit
# signed integer arithmetic, and outputs the index of the resulting class.
#
# Register Usage Convention:
# s0: Pointer to the start of the raw input buffer.
# s1: Pointer to the arch_array (stores layer sizes).
# s2: Pointer to the weights_ptr_array (stores pointers to each layer's weights).
# s3: Pointer to the activations_ptr_array (ping-pongs between two buffers).
# s4: Number of layers in the network.
# s5: Pointer to the current character during parsing.
# s6, s7, s8: General purpose saved registers for loops and pointers.

.globl _start

# ==============================================================================
# DATA SECTION
# ==============================================================================
.data
# Buffer to hold the entire input string from stdin.
input_buffer:   .space 8192

# Buffer for a single character, used for printing the final result.
result_char:    .byte 0
newline:        .asciz "\n"

# ==============================================================================
# BSS SECTION (Uninitialized Data)
# ==============================================================================
.bss
# Parsed network architecture (e.g., 4, 8, 15, 3). Max 10 layers.
.align 4
arch_array:         .space 40

# Array of pointers to the start of each layer's weights. Max 10 layers.
.align 4
weights_ptr_array:  .space 40

# Array of 2 pointers to the activation buffers. We use two buffers and
# ping-pong between them during the forward pass.
.align 4
activations_ptr_array: .space 8

# A large, contiguous block to store all parsed weights.
# The pointers in weights_ptr_array will point into this block.
.align 4
weights_storage:    .space 16384 # 16KB for weights

# Storage for the activation vectors. We need two buffers. The size should be
# large enough for the largest layer. Max layer size of 100 neurons supported.
.align 4
activations_storage_0: .space 100
activations_storage_1: .space 100


# ==============================================================================
# TEXT SECTION (Code)
# ==============================================================================
.text

# ------------------------------------------------------------------------------
# _start: Main entry point
# ------------------------------------------------------------------------------
_start:
    # 1. Read the entire input block from stdin
    la a0, input_buffer
    li a1, 8192
    call read_all

    mv s0, a0 # s0 = Pointer to start of input_buffer

    # 2. Setup pointers to our data structures
    la s1, arch_array
    la s2, weights_ptr_array
    la s3, activations_ptr_array
    la t0, activations_storage_0
    la t1, activations_storage_1
    sw t0, 0(s3) # activations_ptr_array[0] = &activations_storage_0
    sw t1, 4(s3) # activations_ptr_array[1] = &activations_storage_1

    # 3. Parse the input string
    mv a0, s0
    call parse_input
    # parse_input returns the number of layers in a0
    mv s4, a0 # s4 = number of layers

    # 4. Perform the forward pass
    call forward_pass

    # 5. Get the result from the final activation layer
    # Calculate address of final layer size: base + (num_layers-1)*4
    addi t0, s4, -1
    slli t0, t0, 2
    add t0, s1, t0
    lw a1, 0(t0) # a1 = Size of the final layer

    # Get pointer to final activation vector
    addi t0, s4, -2 # last layer index processed was num_layers-2
    andi t1, t0, 1
    xor t1, t1, 1  # get the *other* buffer index
    slli t1, t1, 2
    add t1, s3, t1
    lw a0, 0(t1)   # a0 = pointer to final activation vector

    call argmax

    # 6. Print the resulting index
    call print_result

    # 7. Exit the program
    call exit

# ------------------------------------------------------------------------------
# read_all: Reads input from stdin into a buffer.
# Arguments to function:
#   a0: address of the buffer to read into
#   a1: maximum number of bytes to read (size of the buffer)
# Returns:
#   a0: address of the buffer (unchanged from input a0)
#   The actual number of bytes read is returned by the syscall in its a0,
#   but this function's return a0 is simply the buffer address.
#   It's assumed one read call is sufficient for the problem's input size.
# Syscall 63 (read):
#   a0: file descriptor (0 for stdin)
#   a1: buffer address
#   a2: count (max bytes to read)
#   Returns: number of bytes read in a0, or -1 on error.
# ------------------------------------------------------------------------------
read_all:
    # Save incoming a0 (buffer address) and a1 (count) as they might be overwritten
    # or needed for syscall arguments.
    mv t0, a0   # t0 = buffer_address
    mv t1, a1   # t1 = count (max_bytes_to_read)

    # Prepare arguments for read syscall
    li a0, 0    # fd = 0 (stdin)
    mv a1, t0   # syscall a1 = buffer_address
    mv a2, t1   # syscall a2 = count

    li a7, 63   # Syscall number for read
    ecall

    # After ecall, syscall's return value (bytes read or -1) is in a0.
    # This function is defined to return the buffer address in a0.
    # The problem assumes input fits in one read and is successful.
    # No explicit error check or loop for partial reads is implemented here for simplicity,
    # as per the problem's scope (single input string).
    mv a0, t0   # Return original buffer address
    ret

# ------------------------------------------------------------------------------
# parse_input: Main parsing routine.
# It splits the input string by newlines and calls sub-parsers.
# a0: pointer to the input buffer
# returns: a0: number of layers
# ------------------------------------------------------------------------------
parse_input:
    mv s5, a0 # s5 will be our running pointer through the input buffer

    # --- Find first newline to isolate architecture string ---
    find_newline_1:
        lb t0, 0(s5)
        beq t0, zero, parse_error # Unexpected end of string
        li t1, '\n'
        beq t0, t1, found_newline_1
        addi s5, s5, 1
        j find_newline_1
    found_newline_1:
    sb zero, 0(s5) # Null-terminate the arch string
    addi s5, s5, 1 # Move pointer past the newline
    mv s6, s5      # s6 points to the start of the weights JSON string

    # --- Call architecture parser ---
    # a0 already points to the start of the buffer, which is the arch string
    mv a1, s1 # a1 = &arch_array
    call parse_arch
    mv s4, a0 # s4 = number of layers

    # --- Find second newline to isolate weights string ---
    find_newline_2:
        lb t0, 0(s5)
        beq t0, zero, parse_error
        li t1, '\n'
        beq t0, t1, found_newline_2
        addi s5, s5, 1
        j find_newline_2
    found_newline_2:
    sb zero, 0(s5) # Null-terminate the weights string
    addi s5, s5, 1 # Move pointer past the newline
    mv s7, s5      # s7 points to the start of the input vector string

    # --- Call weights parser ---
    mv a0, s6      # a0 = weights JSON string
    mv a1, s1      # a1 = &arch_array
    mv a2, s2      # a2 = &weights_ptr_array
    la a3, weights_storage
    mv a4, s4      # a4 = number of layers
    call parse_weights

    # --- Call input vector parser ---
    mv a0, s7      # a0 = input vector string
    lw a1, 0(s3)   # a1 = &activations_storage_0
    call parse_vector

    mv a0, s4 # Return number of layers
    ret

# ------------------------------------------------------------------------------
# parse_arch: Parses the comma-separated architecture string.
# a0: string pointer, a1: pointer to arch_array to fill
# returns: a0: number of layers parsed
# ------------------------------------------------------------------------------
parse_arch:
    mv t0, a0 # t0 = current char pointer
    mv t1, a1 # t1 = current arch_array pointer
    li t2, 0  # t2 = number of layers parsed

    parse_arch_loop:
        mv a0, t0
        call parse_number # a0 = parsed number, a1 = new char pointer
        sw a0, 0(t1)      # Store parsed layer size
        mv t0, a1         # Update char pointer

        addi t1, t1, 4    # Move to next slot in arch_array
        addi t2, t2, 1    # Increment layer count

        lb t3, 0(t0)      # Check character after number
        beq t3, zero, parse_arch_done # End of string
        # Assuming comma is the delimiter and parse_number skips it if it's junk
        # If parse_number stops AT the comma, we might need to advance t0 by 1 here.
        # Current parse_number should advance past non-digits.
        j parse_arch_loop

    parse_arch_done:
        mv a0, t2
        ret

# ------------------------------------------------------------------------------
# parse_weights: Parses the simplified JSON weights string.
# a0: string ptr, a1: &arch_array, a2: &weights_ptr_array, a3: &weights_storage
# a4: num_layers
# ------------------------------------------------------------------------------
parse_weights:
    mv s5, a0  # s5 = current char pointer in JSON string
    mv s6, a3  # s6 = current pointer into weights_storage
    mv s7, a2  # s7 = pointer to current slot in weights_ptr_array
    mv t6, a1  # t6 = pointer to arch_array

    # Loop through each layer we need to parse weights for (num_layers - 1)
    li t0, 0 # i = 0
    addi t1, a4, -1 # loop limit (num_weight_matrices)

    parse_weights_layer_loop:
        beq t0, t1, weights_done # if i == num_layers-1, done parsing weights

        # Store the start of this layer's weights in weights_ptr_array
        sw s6, 0(s7)
        addi s7, s7, 4 # next layer's pointer slot

        # Get dimensions for W[i]
        # Inputs to W[i] is arch_array[i], outputs is arch_array[i+1]
        slli t2, t0, 2
        add t2, t6, t2  # &arch_array[i]
        lw t3, 0(t2)    # t3 = inputs to this layer (size of previous activation layer)
        lw t4, 4(t2)    # t4 = outputs of this layer (size of current activation layer)
        mul t5, t3, t4  # t5 = total weights for this layer (rows * cols)

        # Loop to parse all weights for the current layer
        li s8, 0 # weight_count_for_this_layer = 0
        parse_weights_value_loop:
            beq s8, t5, layer_done_parsing_weights # If we've parsed all weights for this layer

            # parse_number expects pointer in a0, returns num in a0, next_ptr in a1
            mv a0, s5
            call parse_number
            sb a0, 0(s6)      # Store parsed 8-bit weight into weights_storage
            mv s5, a1         # Update char pointer (s5) from parse_number's return

            addi s6, s6, 1    # Advance weights_storage pointer by 1 byte
            addi s8, s8, 1    # Increment weight counter for this layer
            j parse_weights_value_loop

        layer_done_parsing_weights:
            addi t0, t0, 1 # i++ (move to next layer's weights)
            j parse_weights_layer_loop

    weights_done:
    ret

# ------------------------------------------------------------------------------
# parse_vector: Parses the comma-separated input vector.
# a0: string pointer, a1: pointer to activation buffer to fill
# ------------------------------------------------------------------------------
parse_vector:
    mv t0, a0 # t0 = current char pointer
    mv t1, a1 # t1 = current activation_buffer pointer

    parse_vector_loop:
        mv a0, t0
        call parse_number # a0=number, a1=new_ptr
        sb a0, 0(t1)      # Store parsed 8-bit activation
        mv t0, a1         # Update char pointer

        addi t1, t1, 1    # Move to next slot in buffer (byte)

        lb t3, 0(t0)      # Check character after number
        beq t3, zero, parse_vector_done # End of string
        # If parse_number consumes the comma, this is fine.
        # If it stops at the comma, we need to advance t0.
        # The refined parse_number should handle skipping non-digits.
        j parse_vector_loop

    parse_vector_done:
    ret

# ------------------------------------------------------------------------------
# parse_number: A simple integer parser.
# Consumes leading non-numeric characters (except '-') until a digit is found.
# Parses the number and returns.
# a0: pointer to string
# returns: a0: parsed number, a1: pointer to char AFTER the last parsed digit
# Registers used: t0 (current char ptr), t1 (result), t2 (sign),
#                 t3 (current char), t4 (temp cmp), t5 (const 10), t6 (parsed_digit_flag)
# Assumes numbers are within reasonable integer limits for 32-bit.
# ------------------------------------------------------------------------------
parse_number:
    mv t0, a0           # t0 = current character pointer
    li t1, 0            # t1 = accumulated result
    li t2, 1            # t2 = sign (1 for positive, -1 for negative)
    li t6, 0            # t6 = flag: has any digit been parsed? 0=no, 1=yes

    # Phase 1: Skip leading junk and find first sign/digit
    skip_leading_junk_loop:
        lb t3, 0(t0)    # t3 = current character
        beq t3, zero, number_parse_finalize # End of string

        # Is it '-'?
        li t4, '-'
        beq t3, t4, sign_handler

        # Is it a digit '0'-'9'?
        li t4, '0'
        blt t3, t4, advance_and_continue_skip # If char < '0'
        li t4, '9'
        bgt t3, t4, advance_and_continue_skip # If char > '9'

        # It's a digit. Break skip loop and go to conversion.
        j number_conversion_entry

    advance_and_continue_skip:
        addi t0, t0, 1
        j skip_leading_junk_loop

    sign_handler:
        # Found a '-'. Set sign and advance pointer.
        li t2, -1           # Set sign to negative
        addi t0, t0, 1      # Advance pointer past '-'
        # After a sign, we expect a digit. Fall through to load next char.
        lb t3, 0(t0)        # Load char immediately after '-'
        # Proceed to conversion loop (which will check if this char is a digit)
        j number_conversion_entry


    # Phase 2: Convert sequence of digits
    number_conversion_entry: # t0 points to the char to check, t3 holds this char
    number_conversion_loop:
        # Check if current char t3 is a digit '0'-'9'
        li t4, '0'
        blt t3, t4, number_parse_finalize # If char < '0', end of number part
        li t4, '9'
        bgt t3, t4, number_parse_finalize # If char > '9', end of number part

        # It's a digit. Convert and accumulate.
        li t6, 1            # Mark that at least one digit has been parsed

        li t5, 10           # t5 = 10
        mul t1, t1, t5      # result = result * 10

        addi t3, t3, -'0'   # convert char ASCII value to digit integer value
        add t1, t1, t3      # result = result + digit

        addi t0, t0, 1      # Advance pointer to next character
        lb t3, 0(t0)        # Load next character into t3 for the next loop iteration
        j number_conversion_loop

    number_parse_finalize:
        # If no digits were parsed (t6 is 0), result (t1) is 0.
        # If sign was negative and no digits, result is still 0. This is acceptable.
        mul t1, t1, t2      # Apply sign

        mv a0, t1           # Return parsed number in a0
        mv a1, t0           # Return updated pointer (points to char AFTER last digit, or on non-digit)
        ret

# Placeholder for parse_error if needed later by callers
# parse_number_error:
#    j exit

# ------------------------------------------------------------------------------
# forward_pass: Main loop to propagate activations through the network.
# ------------------------------------------------------------------------------
forward_pass:
    # s1: &arch_array, s2: &weights_ptr_array, s3: &activations_ptr_array, s4: num_layers
    li t0, 0 # t0 = current layer index (c-1, for W[c] and a[c])
             # This means we are calculating a[t0+1] using W[t0] and a[t0]
             # Loop (num_layers - 1) times. If num_layers is L, loop L-1 times.
             # t0 goes from 0 to L-2.

    addi t1, s4, -1 # t1 = loop limit for t0 (L-1 iterations)

    forward_loop:
        beq t0, t1, forward_done # Exit when t0 reaches num_layers - 1

        # Determine which activation buffer is input and which is output
        # Input activations: a[t0]
        # Output activations: a[t0+1]
        andi t2, t0, 1 # t2 = t0 % 2 (0 if t0 is even, 1 if t0 is odd)
                       # This is the index for the INPUT buffer for this iteration
        slli t2, t2, 2 # t2 = offset in activations_ptr_array (0 or 4)
        add t3, s3, t2 # t3 = address of pointer to current input activations
        lw a0, 0(t3)   # a0 = pointer to previous layer's activations (a[t0])

        # Output buffer index will be (t0+1) % 2
        addi t4, t0, 1
        andi t4, t4, 1 # t4 = (t0+1) % 2
        slli t4, t4, 2
        add t5, s3, t4
        lw a4, 0(t5)   # a4 = pointer for current layer's calculated activations (output Z[t0+1])

        # Get pointer to this layer's weights W[t0]
        # (corresponds to layer from arch[t0] to arch[t0+1])
        slli t4, t0, 2 # t4 = t0 * 4
        add t4, s2, t4 # t4 = &weights_ptr_array[t0]
        lw a1, 0(t4)   # a1 = pointer to this layer's weights (W[t0])

        # Get layer dimensions
        # For W[t0]: input size is arch_array[t0], output size is arch_array[t0+1]
        slli t5, t0, 2
        add t5, s1, t5 # t5 = &arch_array[t0]
        lw a2, 0(t5)   # a2 = input size for this layer (neurons in layer t0)
        lw a3, 4(t5)   # a3 = output size for this layer (neurons in layer t0+1)

        # Perform matrix-vector multiplication Z[t0+1] = W[t0] * a[t0]
        # Output is stored in a4
        call matrix_vector_mult

        # Apply ReLU, unless it's the processing for the *final output layer*
        # The loop for t0 goes from 0 to num_layers-2.
        # When t0 = num_layers-2, we are calculating the final output vector.
        addi t5, t0, 1 # t5 = t0+1. This is the index of the layer whose activations we just computed.
                       # If t5 == num_layers-1, it's the final layer.
        beq t5, t1, skip_relu # if (t0+1 == num_layers-1), then it's the output layer computation.

        # a0 for relu is the output buffer from mat_mul (which is in a4)
        mv a0, a4
        mv a1, a3 # a1 = size of the vector (output size of current layer)
        call relu

    skip_relu:
        addi t0, t0, 1 # t0++ (move to process next layer)
        j forward_loop

    forward_done:
        ret

# ------------------------------------------------------------------------------
# matrix_vector_mult: Performs Z[c] = W[c] * a[c-1]
# a0: &a[c-1] (input activations)
# a1: &W[c] (weights for current layer)
# a2: in_size (number of neurons in previous layer, or cols of W)
# a3: out_size (number of neurons in current layer, or rows of W)
# a4: &Z[c] (result buffer for weighted sums)
# ------------------------------------------------------------------------------
matrix_vector_mult:
    # s6, s7, s8 are available as callee-saved if needed, but using t-regs for now.
    # We need to be careful if this function calls others that might clobber t-regs.
    # It doesn't, so we are fine.

    # Outer loop: for each output neuron (j from 0 to out_size-1)
    li t0, 0 # t0 = j (current output neuron index)
    outer_loop:
        beq t0, a3, mat_mul_done # if j == out_size, exit

        # Inner loop: for each input neuron (k from 0 to in_size-1)
        li t1, 0 # t1 = k (current input neuron index / weight column index)
        li t2, 0 # t2 = sum for Z[c][j] = 0
        inner_loop:
            beq t1, a2, inner_done # if k == in_size, exit inner loop

            # Load activation a[c-1][k]
            add t3, a0, t1  # t3 = &a[c-1][k]
            lb t4, 0(t3)    # t4 = a[c-1][k] (8-bit signed)
            # Sign extend t4 before multiplication if necessary, but mul handles it.
            # However, intermediate products can exceed 8-bit. Sum (t2) is 32-bit.

            # Load weight W[c][j][k]
            # Weights are stored row-major: W[row][col] = W[j][k]
            # Offset = j * in_size + k
            mul t5, t0, a2  # t5 = j * in_size (row_offset)
            add t5, t5, t1  # t5 = j * in_size + k (element_offset within W[c])
            add t5, a1, t5  # t5 = &W[c][j][k]
            lb t6, 0(t5)    # t6 = W[c][j][k] (8-bit signed)

            # Multiply and accumulate: sum += W[j][k] * a[k]
            # mul performs 32x32 -> 32 LSB. For 8-bit * 8-bit, max is 127*127 or -128*-128.
            # 127*127 = 16129. -128*-128 = 16384. These fit in 16 bits.
            # The sum can grow larger. Max sum for IrisNet (e.g. 15 inputs): 15 * 127 * 127 is too large.
            # The problem states "All weights and intermediate values must be treated as 8-bit signed integers".
            # This implies the *result* of each Z_j should be clamped, not necessarily intermediate products.
            # "The formula is Z[c] = W[c] * a[c-1]". The sum is Z_j.
            # Let's assume the sum t2 can be > 8-bit, then clamped.

            # Sign extend operands before multiplication if they are to be treated as full 32-bit signed values
            # for the mul instruction to ensure correct result if intermediate products were larger.
            # However, since they are loaded as bytes and then used in `mul`,
            # they are already sign-extended by `lb` if their MSB (bit 7) is 1.
            # RARS `mul` instruction: rd = rs1 * rs2 (lower 32 bits of product).
            # If t4 and t6 are 8-bit signed values loaded by `lb`, they are sign-extended to 32 bits.
            # So, `mul t4, t4, t6` should be correct.
            # Let's re-verify: `lb` sign-extends. So t4 and t6 are 32-bit signed values representing the 8-bit numbers.
            # The product will be correct.
            mul t4, t4, t6  # product = W_jk * a_k
            add t2, t2, t4  # sum += product

            addi t1, t1, 1 # k++
            j inner_loop

        inner_done:
            # Clamp the sum t2 to 8-bit signed range [-128, 127]
            # This is Z[c][j] before ReLU (or for final output).
            li t3, 127
            bgt t2, t3, clamp_high_mvm
            li t3, -128 # Note: RISC-V `li` can load -128 directly
            blt t2, t3, clamp_low_mvm
            j clamp_done_mvm
        clamp_high_mvm:
            li t2, 127
            j clamp_done_mvm
        clamp_low_mvm:
            li t2, -128
        clamp_done_mvm:

            # Store result Z[c][j] into the output activation buffer
            add t3, a4, t0 # t3 = &Z[c][j]
            sb t2, 0(t3)   # Store the clamped 8-bit value

        addi t0, t0, 1 # j++ (next output neuron)
        j outer_loop

    mat_mul_done:
    ret

# ------------------------------------------------------------------------------
# relu: Applies ReLU activation function element-wise: a[c][j] = max(0, Z[c][j])
# a0: pointer to vector (current layer's Z values, to be updated to a values)
# a1: size of vector (number of neurons in current layer)
# ------------------------------------------------------------------------------
relu:
    li t0, 0 # t0 = i = 0 (index for vector elements)
    relu_loop:
        beq t0, a1, relu_done # if i == size, exit

        add t1, a0, t0 # t1 = &vector[i]
        lb t2, 0(t1)   # t2 = vector[i] (8-bit signed value)

        # Correctly sign-extend the 8-bit value to 32 bits for comparison
        # `lb` already sign-extends, but for clarity or if it was from an unsigned load,
        # this sequence is slli t2, t2, 24; srai t2, t2, 24.
        # Since lb does sign-extend, t2 is already a 32-bit sign-extended value.

        # if (vector[i] < 0) vector[i] = 0
        bgez t2, not_negative_relu # If vector[i] >= 0, skip zeroing
        sb zero, 0(t1)             # vector[i] = 0

    not_negative_relu:
        addi t0, t0, 1 # i++
        j relu_loop

    relu_done:
    ret


# ------------------------------------------------------------------------------
# argmax: Finds the index of the maximum value in a vector.
# a0: pointer to vector (final layer's output, before ReLU)
# a1: size of vector (number of output classes)
# returns: a0: index of max value
# ------------------------------------------------------------------------------
argmax:
    # Handle edge case: if size is 0 or 1
    blez a1, argmax_empty_or_single # If size <= 0, handle (though problem implies >=1)
    li t5, 1
    beq a1, t5, argmax_single_element

    # Initialize max_val with the first element
    lb t1, 0(a0)     # t1 = max_val = vector[0] (8-bit, sign-extended by lb)
    li t2, 0         # t2 = max_idx = 0

    li t0, 1 # t0 = i = 1 (start comparison from the second element)
    argmax_loop:
        beq t0, a1, argmax_done # if i == size, exit

        add t3, a0, t0   # t3 = &vector[i]
        lb t4, 0(t3)     # t4 = current_val = vector[i] (8-bit, sign-extended by lb)

        # No need for explicit slli/srai as lb sign-extends.

        ble t4, t1, not_new_max_argmax # if current_val <= max_val, continue

        # New max found
        mv t1, t4 # max_val = current_val
        mv t2, t0 # max_idx = i

    not_new_max_argmax:
        addi t0, t0, 1 # i++
        j argmax_loop

    argmax_done:
        mv a0, t2 # Return index in a0
        ret

    argmax_empty_or_single: # Should not happen for this problem's constraints (3 classes)
        li a0, 0 # Default to 0 or an error indicator
        ret
    argmax_single_element:
        li a0, 0 # Index of the only element is 0
        ret

# ------------------------------------------------------------------------------
# print_result: Prints the final integer result (0, 1, or 2) to stdout,
# followed by a newline.
# a0: integer result
# ------------------------------------------------------------------------------
print_result:
    # Save a0 (result) as it's used by syscalls
    mv s8, a0

    # Convert integer to ASCII character
    la t0, result_char
    addi s8, s8, '0'
    sb s8, 0(t0)

    # Use 'write' syscall to print the character
    li a0, 1          # stdout
    la a1, result_char
    li a2, 1          # length = 1 char
    li a7, 64         # syscall write
    ecall

    # Print newline
    li a0, 1          # stdout
    la a1, newline
    li a2, 1          # length of newline string (just '\n')
    li a7, 64         # syscall write
    ecall
    ret

# ------------------------------------------------------------------------------
# exit: Terminates the program
# ------------------------------------------------------------------------------
exit:
    li a7, 93 # ecall exit
    ecall

# ------------------------------------------------------------------------------
# parse_error: Simple error handler placeholder
# ------------------------------------------------------------------------------
parse_error:
    # A more robust error handler would print a message to stderr.
    # For now, just exit. This label can be jumped to from parsing functions
    # if an unrecoverable error is detected.
    # Example: print "Error\n"
    # la a1, error_msg
    # li a2, 6
    # li a0, 1 stdout (or 2 for stderr if supported easily)
    # li a7, 64
    # ecall
    j exit

# Minimal .data additions if an error message was desired:
# .data
# ...
# error_msg: .asciz "Error\n"
