.data
architecture_str_buffer: .space 100
architecture_array: .space 40 # Assuming max 10 layers, 4 bytes per int
number_buffer: .space 12 # For atoi conversion, max 11 digits + null terminator
newline: .asciz "\n"
debug_msg_arch_array: .asciz "Architecture Array: "
debug_msg_num_layers: .asciz "Number of Layers: "
comma_char: .asciz "," # Not strictly needed as a variable, but can be useful

# Buffers and data structures for weights parsing (Etapa 2)
json_str_buffer: .space 4096       # Buffer for the entire JSON string
all_weights_buffer: .space 2048    # Buffer to store all weights (e.g., up to 2KB of weights)
                                   # Max layers = 10 (from architecture_array size 40 / 4 bytes per int)
l_weights_ptr_array: .space 40     # Array to store pointers to the start of each layer's weights (10 layers * 4 bytes/ptr)

debug_msg_weights_loaded: .asciz "Weights loaded. First few weights of layer 1: "
debug_msg_json_prompt: .asciz "Enter JSON weights string: "

# Buffers and data structures for input activations (Etapa 3)
input_str_buffer: .space 50        # Buffer for the input flower data string "55,42,14,2"
input_activations_array: .space 4  # Buffer to store 4 input activations as bytes (-128 to 127)

debug_msg_input_prompt: .asciz "Enter flower input data string (e.g., 55,42,14,2): "
debug_msg_input_activations: .asciz "Input Activations (as bytes): "

# Buffers for intermediate activations (Etapa 4)
# Size should be max neurons in any layer. Let's use 64 for now.
activation_buffer_A: .space 64
activation_buffer_B: .space 64
debug_msg_layer_output: .asciz "Output of Layer X: " # X will be filled dynamically
debug_msg_argmax_index: .asciz "Argmax Index (Predicted Class): "

.text
.globl _start

_start:
    # Call read_architecture function
    jal ra, read_architecture
    # After read_architecture returns, s2 holds the number of layers.
    # a0 will contain the return value of read_architecture if it was explicitly set,
    # but here we assume s2 holds the count.

    # Debugging: Print the number of layers
    la a0, debug_msg_num_layers
    jal ra, puts
    mv a0, s2 # s2 has the number of layers
    la a1, number_buffer # Use number_buffer as a temporary buffer for itoa
    jal ra, itoa
    mv a0, a1 # itoa returns buffer address in a0
    jal ra, puts

    # Debugging: Print the contents of architecture_array
    la a0, debug_msg_arch_array
    jal ra, puts

    la s4, architecture_array # s4 = pointer to current element in architecture_array
    li s5, 0                  # s5 = loop counter for printing array

print_arch_loop:
    beq s5, s2, end_print_arch_loop # If counter == num_layers, exit loop

    lw a0, 0(s4)              # a0 = architecture_array[i]
    la a1, number_buffer      # Buffer for itoa
    jal ra, itoa
    mv a0, a1                 # itoa returns buffer address in a0, move to a0 for puts
    jal ra, puts              # Print the number

    addi s4, s4, 4            # Move to next word in array
    addi s5, s5, 1            # Increment counter
    j print_arch_loop

end_print_arch_loop:

    # Debugging: Print the contents of architecture_array
    la a0, debug_msg_arch_array
    jal ra, puts

    # s2 at this point is N_arch_layers (e.g. 4 for [L0,L1,L2,L3])
    # We need to use a different register for iterating architecture_array if s2 is used elsewhere
    # or ensure s2 is restored if modified by callees. puts/itoa save s0-s1.
    # For printing architecture_array, s2 is the count.
    mv t0, s2                 # t0 = N_arch_layers, use t0 for loop bound
    la s4, architecture_array # s4 = pointer to current element in architecture_array
    li s5, 0                  # s5 = loop counter for printing array

print_arch_loop:
    beq s5, t0, end_print_arch_loop # If counter == N_arch_layers, exit loop

    lw a0, 0(s4)              # a0 = architecture_array[i]
    la a1, number_buffer      # Buffer for itoa
    jal ra, itoa
    mv a0, a1                 # itoa returns buffer address in a0, move to a0 for puts
    jal ra, puts              # Print the number

    addi s4, s4, 4            # Move to next word in array
    addi s5, s5, 1            # Increment counter
    j print_arch_loop

end_print_arch_loop:

    # Prompt for and read the JSON weights string
    la a0, debug_msg_json_prompt
    jal ra, puts
    la a0, json_str_buffer
    li a1, 4096 # Max length for gets
    jal ra, gets

    # Call parse_weights_json
    # Arguments: a0=json_str_buffer, a1=architecture_array, a2=all_weights_buffer, a3=l_weights_ptr_array
    # s2 (N_arch_layers) is implicitly passed as it's in s2. parse_weights_json expects this.
    la a0, json_str_buffer
    la a1, architecture_array
    la a2, all_weights_buffer
    la a3, l_weights_ptr_array
    # s2 correctly holds N_arch_layers here. parse_weights_json will save it,
    # use s2 internally as num_weight_matrices, and then restore original N_arch_layers to s2.
    jal ra, parse_weights_json

    # Debugging: Print the first few weights of the first layer
    la a0, debug_msg_weights_loaded
    jal ra, puts

    la s3, l_weights_ptr_array # s3 = &l_weights_ptr_array[0]
    lw s4, 0(s3)             # s4 = pointer to start of layer 1 weights

    # Determine how many weights are in layer 1: architecture_array[0] * architecture_array[1]
    # s2 now holds the original N_arch_layers (restored by parse_weights_json)
    # Ensure s2 is indeed restored if these lines are reached and s2 is critical.
    # (Verified: parse_weights_json restores s2 from its stack frame)
    bge zero, s2, skip_weights_print # If N_arch_layers <= 0 (no layers or error)
    li t0, 1
    bge t0, s2, skip_weights_print # If N_arch_layers == 1 (e.g. [N_in] only, no weights)

    la t0, architecture_array
    lw t1, 0(t0) # t1 = num_inputs (e.g., arch[0])
    lw t2, 4(t0) # t2 = num_neurons_layer1 (e.g., arch[1])
    mul t3, t1, t2 # t3 = total weights for layer 1

    # Print up to, say, 5 weights or t3, whichever is smaller
    li t4, 5       # Max weights to print for debug
    blt t3, t4, set_print_count_to_t3_val
    mv t5, t4      # t5 = number of weights to print (e.g. 5)
    j print_weights_debug_loop_start_val
set_print_count_to_t3_val:
    mv t5, t3      # t5 = number of weights to print (total weights if < 5)

print_weights_debug_loop_start_val:
    li s5, 0       # s5 = loop counter for printing weights

print_weights_debug_loop_val:
    beq s5, t5, end_print_weights_debug_loop_val
    beq s4, zero, end_print_weights_debug_loop_val # Safety: if pointer is null

    lb a0, 0(s4)   # Load byte weight. lb sign-extends.
    la a1, number_buffer
    jal ra, itoa   # Convert the byte to string
    mv a0, a1
    jal ra, puts

    addi s4, s4, 1 # Next byte weight
    addi s5, s5, 1 # Increment counter
    j print_weights_debug_loop_val

end_print_weights_debug_loop_val:
skip_weights_print:

    # Prompt for and read the input flower data string
    la a0, debug_msg_input_prompt
    jal ra, puts
    # Arguments for read_input_activations:
    # a0: Pointer to input_str_buffer
    # a1: Pointer to input_activations_array (byte array)
    # a2: Pointer to number_buffer (general purpose for atoi)
    la a0, input_str_buffer
    la a1, input_activations_array
    la a2, number_buffer
    jal ra, read_input_activations
    # t0 may contain the number of activations read (optional, from read_input_activations)

    # Debugging: Print the contents of input_activations_array
    la a0, debug_msg_input_activations
    jal ra, puts

    la s4, input_activations_array # s4 = pointer to current element in input_activations_array
    li s5, 0                       # s5 = loop counter for printing activations
    li t5, 4                       # t5 = expected number of activations to print (max 4)
    # If t0 from read_input_activations contains actual count, could use that: mv t5, t0

print_input_acts_loop:
    beq s5, t5, end_print_input_acts_loop

    lb a0, 0(s4)              # Load byte activation (lb sign-extends)
    la a1, number_buffer      # Buffer for itoa
    jal ra, itoa
    mv a0, a1                 # itoa returns buffer address in a0, move to a0 for puts
    jal ra, puts              # Print the number

    addi s4, s4, 1            # Move to next byte in array
    addi s5, s5, 1            # Increment counter
    j print_input_acts_loop

end_print_input_acts_loop:

    # --- Perform Full Inference (Forward Pass) ---
    # s2 contains N_arch_layers (e.g., 3 for L0,L1,L2)
    # s4 is already la s4, architecture_array from previous debug. If not, load it.
    # s5 needs to be la s5, l_weights_ptr_array.

    # Initialize s-registers for the loop (ensure they are saved if used across calls in a real scenario)
    # For _start, we can use them more freely, but good practice to note their roles.
    # s2: N_arch_layers (number of entries in architecture_array)
    # s4: architecture_array_ptr
    # s5: l_weights_ptr_array_ptr
    # s6: current_input_activations_ptr
    # s7: current_output_activations_ptr
    # s8: layer_idx (0 to num_weight_layers - 1)
    # s9: num_weight_layers
    # s10: activation_buffer_A_ptr
    # s11: activation_buffer_B_ptr

    la s4, architecture_array   # Ensure s4 is loaded
    la s5, l_weights_ptr_array  # Load s5

    li t0, 2 # Minimum N_arch_layers for one weight matrix
    blt s2, t0, skip_full_inference # If N_arch_layers < 2, skip processing

    addi s9, s2, -1 # s9 = num_weight_layers = N_arch_layers - 1

    la s6, input_activations_array # First input is from the parsed flower data
    la s10, activation_buffer_A
    la s11, activation_buffer_B
    mv s7, s10                     # First output goes to activation_buffer_A

    li s8, 0                       # layer_idx = 0

inference_loop:
    beq s8, s9, end_inference_loop # If layer_idx == num_weight_layers, all layers processed

    # Prepare arguments for matrix_vector_mult_relu:
    # a0 = prev_layer_activations_ptr (s6)
    # a1 = current_layer_weights_ptr (from l_weights_ptr_array[s8])
    # a2 = num_neurons_prev_layer    (from architecture_array[s8])
    # a3 = num_neurons_current_layer (from architecture_array[s8+1])
    # a4 = output_activations_ptr    (s7)

    mv a0, s6

    slli t0, s8, 2          # t0 = layer_idx * 4
    add t1, s5, t0          # t1 = &l_weights_ptr_array[layer_idx]
    lw a1, 0(t1)            # a1 = l_weights_ptr_array[layer_idx]

    add t1, s4, t0          # t1 = &architecture_array[layer_idx] (abusing t0 from previous calc)
    lw a2, 0(t1)            # a2 = architecture_array[layer_idx] (num_neurons_prev_layer)

    addi t2, s8, 1          # t2 = layer_idx + 1
    slli t3, t2, 2          # t3 = (layer_idx + 1) * 4
    add t1, s4, t3          # t1 = &architecture_array[layer_idx + 1]
    lw a3, 0(t1)            # a3 = architecture_array[layer_idx + 1] (num_neurons_current_layer)

    mv a4, s7

    jal ra, matrix_vector_mult_relu

    # Debug: Print output of the current layer (s8 processing, output is for layer s8+1)
    # Output is in s7, count is a3 (num_neurons_current_layer)

    # Simple print for layer number (s8+1)
    # This is a bit tricky to print "Layer X" nicely without more complex string manipulation
    # For now, just print the activations.
    # la t0, debug_msg_layer_output
    # jal ra, puts

    # la t6, number_buffer # temp for itoa for layer number
    # mv t0, s8
    # addi t0, t0, 1 # Print layer number as 1-indexed
    # mv a0, t0
    # la a1, t6
    # jal ra, itoa
    # mv a0, a1
    # jal ra, puts # Prints the layer number

    # mv t0, s7 # Pointer to data to print
    # mv t1, a3 # Count of items to print
    # Call a generic print_array function if available, or inline loop:
    # (Inline loop for now for simplicity, similar to previous debug prints)
    # la s0_temp, 0(t0) # Use a temporary s register if needed for loop pointer
    # li s1_temp, 0     # Loop counter
    # print_current_layer_acts_loop:
    #   beq s1_temp, t1, end_print_current_layer_acts_loop
    #   lb a0, 0(s0_temp)
    #   la a1, number_buffer
    #   jal ra, itoa
    #   mv a0, a1
    #   jal ra, puts
    #   addi s0_temp, s0_temp, 1
    #   addi s1_temp, s1_temp, 1
    #   j print_current_layer_acts_loop
    # end_print_current_layer_acts_loop:
    # (Skipping detailed per-layer print for brevity in this step, can be added if needed)

    # Swap buffers for next iteration: output (s7) becomes next input (s6)
    # And select the other buffer for the next output.
    mv s6, s7 # Current output s7 becomes next input s6

    # Determine next output buffer s7
    beq s7, s10, use_buffer_B_for_output # If current output s7 was buffer_A (s10)
    mv s7, s10                         # Else, current output s7 was buffer_B (s11), so next is buffer_A (s10)
    j swapped_buffers
use_buffer_B_for_output:
    mv s7, s11                         # Next output is buffer_B (s11)
swapped_buffers:

    addi s8, s8, 1 # layer_idx++
    j inference_loop

end_inference_loop:
    # The final activations are in s6 (which was the s7 of the last layer processed)
    # The number of output neurons is architecture_array[N_arch_layers-1]
    # This is architecture_array[s2-1]
    # Or, it's the 'a3' value from the last call to matrix_vector_mult_relu

    # Debug: Print final output activations (from s6)
    la a0, debug_msg_layer_output # Could be "Final Output Activations:"
    jal ra, puts

    # Get count of output neurons: architecture_array[N_arch_layers - 1]
    addi t0, s2, -1   # t0 = N_arch_layers - 1 (index of last layer size)
    slli t1, t0, 2    # t1 = offset for last layer size
    add t1, s4, t1    # t1 = &architecture_array[last_layer_idx]
    lw t5, 0(t1)      # t5 = num_neurons_in_output_layer

    mv t6, s6         # t6 = pointer to final activations
    li s5, 0          # s5 = loop counter

print_final_acts_loop:
    beq s5, t5, end_print_final_acts_loop

    lb a0, 0(t6)      # Load byte activation
    la a1, number_buffer
    jal ra, itoa
    mv a0, a1
    jal ra, puts

    addi t6, t6, 1
    addi s5, s5, 1
    j print_final_acts_loop

end_print_final_acts_loop:

    # Call argmax with final activations
    # a0 = pointer to final activations (is in s6)
    # a1 = number of output neurons (is in t5 from the final print loop)
    mv a0, s6
    mv a1, t5
    jal ra, argmax
    # Result (argmax index) is in a0

    # Print the argmax index
    la s0, debug_msg_argmax_index # Using s0 as temp for string addr
    # mv a0, s0 (Oops, a0 has the result, need to save it or print directly)
    # Save result of argmax before printing string
    mv s1, a0 # s1 = argmax_result (save the result from argmax's a0)

    # mv a0, s0 # This was for printing debug_msg_argmax_index; skip for final output.
    # jal ra, puts # Skip printing "Argmax Index (Predicted Class): "

    # Print only the numerical result of argmax (from s1)
    mv a0, s1 # a0 = argmax_result (the number to print)
    la a1, number_buffer
    jal ra, itoa
    mv a0, a1
    jal ra, puts

skip_full_inference:
    # Exit program
    jal ra, exit

#-------------------------------------------------------------------------------
# read_architecture: Reads the first line of input (network architecture)
# Input: None
# Output:
#   - architecture_array populated with integers
#   - s2 will hold the number of layers (count of numbers read)
# Registers used:
#   s0: pointer to current position in architecture_str_buffer
#   s1: pointer to current position in architecture_array
#   s2: counter for numbers read (number of layers)
#   s3: pointer to current position in number_buffer
#   t0, t1, t2, t3, a0, a1: temporary registers
#-------------------------------------------------------------------------------
read_architecture:
    # Save return address and callee-saved registers
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    sw s3, 12(sp)

    # Get the architecture string from input
    la a0, architecture_str_buffer
    li a1, 100 # Max length for gets
    jal ra, gets

    # Initialize pointers and counter
    la s0, architecture_str_buffer  # s0 = &architecture_str_buffer[0]
    la s1, architecture_array       # s1 = &architecture_array[0]
    li s2, 0                        # s2 = 0 (number of layers read)
    la s3, number_buffer            # s3 = &number_buffer[0] (write pointer for current number string)
    li t3, 0                        # t3 = flag to indicate if number_buffer has content

parse_char_loop:
    lb t0, 0(s0)                    # t0 = architecture_str_buffer[i]

    # Check for terminators or separator
    beq t0, zero, process_last_number_and_end # Null terminator from gets
    li t1, '\n'
    beq t0, t1, process_last_number_and_end # Newline (should be handled by gets, but defensive)
    li t1, ','
    beq t0, t1, process_number_and_continue # Comma separator

    # Check if t0 is a digit
    li t1, '0'
    li t2, '9'
    blt t0, t1, char_not_valid_or_end # If t0 < '0' (should not happen with valid input)
    bgt t0, t2, char_not_valid_or_end # If t0 > '9' (should not happen with valid input)

    # It's a digit, copy to number_buffer
    sb t0, 0(s3)                    # number_buffer[j] = t0
    addi s3, s3, 1                  # j++
    li t3, 1                        # Mark that number_buffer has content
    addi s0, s0, 1                  # i++
    j parse_char_loop

char_not_valid_or_end:
    # This case implies an invalid character in the input string or end of string.
    # If number_buffer has content, process it. Otherwise, it might be an empty string or invalid start.
    beq t3, zero, end_parse_loop_direct # If no number was being parsed, just end.
    # Fall through to process the number if t3 is 1.

process_last_number_and_end:
    # If there's a pending number in number_buffer, process it.
    beq t3, zero, end_parse_loop_direct # If buffer empty (e.g. "1,2," or empty input), go to end
    # Fall through to process_number_logic if t3 is 1

process_number_and_continue: # Called when a comma is found or falling through for terminators
    # Terminate number_buffer with null (only if there was content)
    li t1, 0
    sb t1, 0(s3)

    # Convert number_buffer to integer using atoi
    la a0, number_buffer
    jal ra, atoi                    # Result is in a0

    # Store the integer in architecture_array
    sw a0, 0(s1)

    # Increment pointers and counter
    addi s1, s1, 4                  # Move to next word in architecture_array
    addi s2, s2, 1                  # Increment number of layers read

    # Reset number_buffer pointer and content flag
    la s3, number_buffer
    li t3, 0                        # Reset content flag

    # Check if we should exit the main loop
    lb t0, 0(s0)                    # Current char (could be ',', '\n', or '\0')
    beq t0, zero, end_parse_loop_direct # If it was null, end.
    li t1, '\n'
    beq t0, t1, end_parse_loop_direct # If it was newline, end.

    # If it was a comma, we need to advance s0 and continue parsing
    li t1, ','
    beq t0, t1, advance_and_continue

    # If it's none of the above, it's an unexpected situation, but for valid input,
    # this path shouldn't be hit after processing a number unless it's the end.
    j end_parse_loop_direct # Default to ending if not a comma

advance_and_continue:
    addi s0, s0, 1                  # Move past the comma
    j parse_char_loop               # Continue parsing for the next number

end_parse_loop_direct: # Used for direct jumps to the end
    # The number of layers is in s2
    # architecture_array is populated

    # Restore callee-saved registers and return address
    # s3 was used as a temp register (pointer to number_buffer), no need to keep its final value in s3 itself.
    # s2 (layer count) is important.
    lw ra, 28(sp)
    lw s0, 24(sp) # Original s0, s1, s2, s3 values are restored
    lw s1, 20(sp)
    # s2 is already up-to-date with the layer count, or being restored if we consider it callee-saved.
    # For this function's purpose, s2 is effectively a return value.
    # We will keep the final value of s2.
    # lw s2, 16(sp) # If we strictly restore all, uncomment. But s2 is our output.
    # lw s3, 12(sp)

    # Restore s0, s1, and the original s3 if they were used for other things before call.
    # For now, assuming s0, s1, s2, s3 are primarily for this function's internal work,
    # but s2 needs to persist its final value.
    # So, we restore s0, s1, and the original s3 that was saved. The current s3 (number_buffer ptr) is volatile.
    # The s2 that was saved at 16(sp) is the initial value (0). The current s2 holds the count.
    # To return s2's value, we can either rely on it being in s2 or move it to a0.
    # Standard calling convention might expect return in a0 if not fitting in saved regs.
    # For now, let's assume s2 is fine as is, or the caller knows to check s2.

    # Restore only those registers that are strictly callee-saved according to convention
    # and were not meant to return a value.
    # s0, s1 are callee-saved. s2 is also callee-saved, but we are using it as a return value.
    # This is a common pattern for "returning" small integers in saved registers.
    # s3 is also callee-saved.

    # Let's restore all saved s-registers to their original state before the function call,
    # and if s2 is the output, it should be moved to a0 if we were strictly following ABI for return values.
    # However, the prompt says "s2 will hold the number of layers", implying it's okay to leave it in s2.

    lw s3, 12(sp) # Restore original s3
    # s2 contains the count, which we want to preserve as an output.
    # So we don't restore s2 from stack if it's the intended output register.
    # If the caller needs the original s2, this function violates that.
    # Let's assume the caller expects the count in s2.
    lw s1, 20(sp) # Restore original s1
    lw s0, 24(sp) # Restore original s0
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

#-------------------------------------------------------------------------------
# Helper functions (to be copied or adapted from lab10.s or lab91.s)
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# gets: reads a line from stdin until newline or EOF
# arguments:
#   a0: address of buffer to store string
#   a1: maximum number of characters to read (including null)
# returns:
#   a0: address of buffer (unchanged)
#-------------------------------------------------------------------------------
gets:
    addi sp, sp, -12
    sw ra, 0(sp)
    sw s0, 4(sp) # buffer pointer
    sw s1, 8(sp) # count

    mv s0, a0       # s0 = buffer
    li s1, 0        # s1 = count = 0
    li t2, 10       # newline char code

gets_loop:
    # Check if buffer full (count == max_chars - 1)
    addi t0, s1, 1
    beq t0, a1, gets_end_loop

    # Read char
    li a7, 63       # ecall read_char
    ecall
    # a0 contains the char, or -1 if EOF

    beq a0, t2, gets_end_loop   # if char == '\n', end loop
    li t0, -1
    beq a0, t0, gets_end_loop   # if char == EOF, end loop

    sb a0, 0(s0)    # store char in buffer
    addi s0, s0, 1  # buffer++
    addi s1, s1, 1  # count++
    j gets_loop

gets_end_loop:
    li t0, 0        # null terminator
    sb t0, 0(s0)    # store null terminator

    # Return original buffer address in a0 (already there)
    lw ra, 0(sp)
    lw s0, 4(sp)
    lw s1, 8(sp)
    addi sp, sp, 12
    ret

#-------------------------------------------------------------------------------
# atoi: converts a null-terminated string to an integer
# arguments:
#   a0: address of the string
# returns:
#   a0: the integer value
#-------------------------------------------------------------------------------
atoi:
    addi sp, sp, -20
    sw ra, 0(sp)
    sw s0, 4(sp)  # string pointer
    sw s1, 8(sp)  # current_sum
    sw s2, 12(sp) # sign
    sw t0, 16(sp) # current char

    mv s0, a0       # s0 = &string
    li s1, 0        # current_sum = 0
    li s2, 1        # sign = 1 (positive)

    # Check for sign
    lb t0, 0(s0)
    li t1, '-'
    beq t0, t1, atoi_negative
    li t1, '+'
    beq t0, t1, atoi_skip_sign
    j atoi_loop # no sign or not '+'

atoi_negative:
    li s2, -1       # sign = -1
    addi s0, s0, 1  # s0++
    j atoi_loop

atoi_skip_sign:
    addi s0, s0, 1  # s0++

atoi_loop:
    lb t0, 0(s0)    # t0 = string[i]
    beq t0, zero, atoi_end # if t0 == '\0', end

    li t1, '0'
    blt t0, t1, atoi_invalid_char # if t0 < '0', invalid
    li t1, '9'
    bgt t0, t1, atoi_invalid_char # if t0 > '9', invalid

    # Convert char to digit
    li t1, '0'
    sub t0, t0, t1  # t0 = digit

    # current_sum = current_sum * 10 + digit
    li t1, 10
    mul s1, s1, t1
    add s1, s1, t0

    addi s0, s0, 1  # s0++
    j atoi_loop

atoi_invalid_char:
    # Optional: handle error, for now, just end conversion
    j atoi_end

atoi_end:
    mul a0, s1, s2  # result = current_sum * sign

    lw ra, 0(sp)
    lw s0, 4(sp)
    lw s1, 8(sp)
    lw s2, 12(sp)
    lw t0, 16(sp)
    addi sp, sp, 20
    ret

#-------------------------------------------------------------------------------
# itoa: converts an integer to a null-terminated string
# arguments:
#   a0: integer to convert
#   a1: address of buffer to store string (must be large enough)
# returns:
#   a0: address of buffer (unchanged from a1)
#   The buffer at a1 will be populated with the string.
#-------------------------------------------------------------------------------
itoa:
    addi sp, sp, -28
    sw ra, 0(sp)
    sw s0, 4(sp)  # number
    sw s1, 8(sp)  # buffer pointer
    sw s2, 12(sp) # temp pointer for reversing
    sw s3, 16(sp) # char count / temp for reversing
    sw s4, 20(sp) # is_negative flag
    sw t0, 24(sp) # temp digit/char

    mv s0, a0       # s0 = number
    mv s1, a1       # s1 = buffer_start
    li s4, 0        # is_negative = 0

    beq s0, zero, itoa_zero # Handle n = 0 separately

    # Handle negative numbers
    bgez s0, itoa_positive
    li s4, 1        # is_negative = 1
    neg s0, s0      # number = -number
    li t0, '-'
    sb t0, 0(s1)    # buffer[0] = '-'
    addi s1, s1, 1  # buffer++

itoa_positive:
    mv s2, s1       # s2 points to start of digits (after potential '-')

itoa_conversion_loop:
    rem t0, s0, 10   # t0 = number % 10 (digit)
    div s0, s0, 10   # number = number / 10
    addi t0, t0, '0' # convert digit to char
    sb t0, 0(s2)     # store char in buffer (reversed)
    addi s2, s2, 1   # s2++
    bne s0, zero, itoa_conversion_loop # loop if number != 0

    # Null terminate the reversed string
    li t0, 0
    sb t0, 0(s2)

    # Reverse the string of digits (from s1 or s1+1 up to s2-1)
    mv t0, s1       # t0 = start_of_digits
    addi s3, s2, -1 # s3 = end_of_digits

itoa_reverse_loop:
    blt s3, t0, itoa_reverse_end # if end < start, done

    lb t1, 0(t0)    # t1 = *start
    lb t2, 0(s3)    # t2 = *end
    sb t2, 0(t0)    # *start = t2
    sb t1, 0(s3)    # *end = t1

    addi t0, t0, 1  # start++
    addi s3, s3, -1 # end--
    j itoa_reverse_loop

itoa_reverse_end:
    mv a0, a1       # return original buffer address
    lw ra, 0(sp)
    lw s0, 4(sp)
    lw s1, 8(sp)
    lw s2, 12(sp)
    lw s3, 16(sp)
    lw s4, 20(sp)
    lw t0, 24(sp)
    addi sp, sp, 28
    ret

itoa_zero:
    li t0, '0'
    sb t0, 0(s1)    # buffer[0] = '0'
    addi s1, s1, 1
    li t0, 0
    sb t0, 0(s1)    # buffer[1] = '\0'
    mv a0, a1       # return original buffer address
    # Restore and return (same as itoa_reverse_end)
    lw ra, 0(sp)
    lw s0, 4(sp)
    lw s1, 8(sp)
    lw s2, 12(sp)
    lw s3, 16(sp)
    lw s4, 20(sp)
    lw t0, 24(sp)
    addi sp, sp, 28
    ret

#-------------------------------------------------------------------------------
# puts: prints a null-terminated string to stdout, followed by a newline
# arguments:
#   a0: address of the string
# returns:
#   None
#-------------------------------------------------------------------------------
puts:
    addi sp, sp, -8
    sw ra, 0(sp)
    sw s0, 4(sp) # string pointer

    mv s0, a0       # s0 = &string

puts_loop:
    lb t0, 0(s0)    # t0 = string[i]
    beq t0, zero, puts_end_loop # if t0 == '\0', end

    # Print char
    mv a0, t0
    li a7, 11       # ecall print_char
    ecall

    addi s0, s0, 1  # s0++
    j puts_loop

puts_end_loop:
    # Print newline
    la a0, newline
    lb a0, 0(a0) # load the newline char itself
    li a7, 11       # ecall print_char
    ecall

    lw ra, 0(sp)
    lw s0, 4(sp)
    addi sp, sp, 8
    ret

#-------------------------------------------------------------------------------
# exit: terminates the program
#-------------------------------------------------------------------------------
exit:
    li a7, 10 # ecall exit
    ecall
    # Should not return
    ret

#-------------------------------------------------------------------------------
# parse_weights_json: Parses the JSON string of weights and stores them.
# Arguments:
#   a0 (s8):  Pointer to json_str_buffer
#   a1 (s9):  Pointer to architecture_array (contains neuron counts for each layer)
#   a2 (s10): Pointer to all_weights_buffer (where weights will be stored contiguously)
#   a3 (s11): Pointer to l_weights_ptr_array (to store pointers to start of each layer's weights)
#   s2:       Number of layers in the network (e.g., if arch is [N_in, N_l1, N_l2], num_layers for weights = 2)
#             This is the number of weight matrices.
#
# Registers used:
#   s0: Current read pointer in json_str_buffer
#   s1: Current write pointer in all_weights_buffer
#   s2: Number of weight matrices to parse (derived from num_layers in architecture - 1)
#   s3: Pointer to l_weights_ptr_array (for storing pointers to layer weights)
#   s4: Pointer to architecture_array (neuron_counts)
#   s5: Current layer index being parsed (0 for l1, 1 for l2, etc.)
#   s6: Neurons in current target layer (num_neurons_camada_c)
#   s7: Neurons in current source layer (num_neurons_camada_c-1)
#   s8: Loop counter for neurons in target layer ( iterates 0 to s6-1)
#   s9: Loop counter for weights per neuron (iterates 0 to s7-1)
#   s10: Pointer to number_buffer for atoi
#   t0-t6: Temporary registers
#-------------------------------------------------------------------------------
parse_weights_json:
    addi sp, sp, -64  # Allocate stack space for RA and saved registers
    sw ra, 60(sp)
    sw s0, 56(sp)
    sw s1, 52(sp)
    sw s2, 48(sp) # Number of weight matrices
    sw s3, 44(sp) # l_weights_ptr_array
    sw s4, 40(sp) # architecture_array
    sw s5, 36(sp) # current_layer_index
    sw s6, 32(sp) # neurons_in_target_layer
    sw s7, 28(sp) # neurons_in_source_layer (inputs to current layer)
    sw s8, 24(sp) # neuron_loop_counter
    sw s9, 20(sp) # weight_loop_counter
    sw s10, 16(sp) # number_buffer_ptr
    # s11 is not used here as it's an argument passed in a3, and we use s3 for it.

    # Move arguments to s-registers if they are not already convenient
    mv s0, a0      # s0 = json_str_buffer pointer
    mv s4, a1      # s4 = architecture_array pointer
    mv s1, a2      # s1 = all_weights_buffer pointer (current write head)
    mv s3, a3      # s3 = l_weights_ptr_array pointer

    # s2 already contains the total number of entries in architecture_array (N_arch_layers).
    # The number of weight matrices is N_arch_layers - 1.
    # We save the original s2 (N_arch_layers) on the stack (already done by sw s2, 48(sp)).
    # We then modify s2 to be the count of weight matrices for the parsing loop.
    # At the end, the original s2 will be restored from the stack.

    mv t6, s2      # t6 can be used if N_arch_layers is needed elsewhere before s2 is restored
                   # For this function, we'll just modify s2 for the loop count.
    addi s2, s2, -1 # s2 now holds the number of weight matrices to parse.
                   # This s2 will be used as the loop bound in parse_next_layer_weights.

    la s10, number_buffer # For atoi

    li s5, 0 # current_layer_index = 0 (for "l1", "l2", etc.)

    # Store the pointer to the beginning of the first layer's weights.
    # This is the start of all_weights_buffer itself.
    sw s1, 0(s3)
    addi s3, s3, 4 # Advance pointer for l_weights_ptr_array for the next layer

parse_next_layer_weights:
    # Check if all specified weight matrices have been parsed
    beq s5, s2, parsing_done

    # Skip initial JSON characters until '[[', specific to layer
    # Example: find "l<s5+1>":[[, then start parsing numbers
    # For simplicity, this parser will be very format-specific.
    # It will look for patterns like `[[` to start a matrix, `[` for a row, numbers, `,` and `]`.

skip_to_matrix_start: # Skips '{"lx":[' or ',"lx":['
    lb t0, 0(s0)
    beq t0, zero, parsing_error_unexpected_end # End of string prematurely

    # Skip non-essential characters until we find the first '[' of a matrix
    # This is a simplification: assumes "lx":[[...]] structure
    # A more robust parser would check for "l", then digit, then ":", then "[["
    li t1, '['
    beq t0, t1, found_matrix_bracket # Found one '['
    addi s0, s0, 1
    j skip_to_matrix_start

found_matrix_bracket:
    addi s0, s0, 1 # Move past the first '['
    lb t0, 0(s0)
    li t1, '['
    bne t0, t1, parsing_error_expected_bracket # Expected second '['
    addi s0, s0, 1 # Move past the second '['. Now at the first char of the first number or another '['.

    # Determine matrix dimensions for the current layer s5
    # Weights for layer s5 connect layer s5 (source) to layer s5+1 (target)
    # architecture_array[s5] = num neurons in source layer (inputs to current weight matrix)
    # architecture_array[s5+1] = num neurons in target layer (outputs of current weight matrix, rows of matrix)

    mv t0, s5      # t0 = current_layer_index
    slli t1, t0, 2 # offset for source layer size = current_layer_index * 4
    add t1, s4, t1 # address of architecture_array[current_layer_index]
    lw s7, 0(t1)   # s7 = neurons_in_source_layer (inputs to this layer, or cols for the current neuron's weights)

    addi t0, t0, 1 # t0 = current_layer_index + 1 (target layer)
    slli t1, t0, 2 # offset for target layer size
    add t1, s4, t1 # address of architecture_array[current_layer_index + 1]
    lw s6, 0(t1)   # s6 = neurons_in_target_layer (number of rows in weight matrix)

    li s8, 0 # neuron_loop_counter (for target layer neurons, i.e., rows)

parse_neuron_weights_loop: # Loop for each neuron in the target layer (each row of the matrix)
    # Check if all neurons for this layer are processed
    beq s8, s6, layer_done

    # Skip '[' at the beginning of a neuron's weight list, if present.
    # The first neuron's weights might not have a preceding '[' if the outer skip went to the first number.
    # Subsequent neurons' weights will be preceded by ",[" or just "[".
skip_to_row_start:
    lb t0, 0(s0)
    beq t0, zero, parsing_error_unexpected_end
    li t1, '['
    beq t0, t1, found_row_bracket
    # If it's a digit or '-', we are likely at the start of a number already.
    li t1, '-'
    beq t0, t1, parse_number_value
    li t1, '0'
    li t2, '9'
    blt t0, t1, skip_this_char_row # Not a digit, not '-', not '['
    bgt t0, t2, skip_this_char_row # Not a digit, not '-', not '['
    j parse_number_value          # It's a digit, start parsing number

skip_this_char_row:
    addi s0, s0, 1
    j skip_to_row_start

found_row_bracket:
    addi s0, s0, 1 # Move past the '['. Now at the first char of the number.

    li s9, 0 # weight_loop_counter (for weights of the current neuron, i.e., cols)

parse_weight_loop: # Loop for each weight of the current neuron
    # Check if all weights for this neuron are processed
    beq s9, s7, neuron_done # s7 = neurons_in_source_layer (number of weights for this neuron)

parse_number_value:
    # We are at the start of a number (digit or '-')
    # Copy number string to number_buffer (s10)
    mv t1, s10 # t1 = current write pointer in number_buffer
    li t2, 0   # t2 = length of number string

parse_digit_loop:
    lb t0, 0(s0) # Get char from JSON string

    # Check if it's a digit or leading minus sign
    li t3, '0'
    li t4, '9'
    blt t0, t3, check_char_is_minus_or_end_num
    bgt t0, t4, end_of_number_str
    # It's a digit
    j copy_digit_to_buffer

check_char_is_minus_or_end_num:
    li t3, '-'
    beq t0, t3, copy_digit_to_buffer # If it's a minus sign (allow only at start, t2==0)
    # Any other non-digit char signifies end of number
    j end_of_number_str

copy_digit_to_buffer:
    # Basic check for number_buffer overflow (11 chars + null)
    li t5, 11
    bge t2, t5, parsing_error_num_too_long

    sb t0, 0(t1)   # Store char in number_buffer
    addi t1, t1, 1 # Advance number_buffer pointer
    addi s0, s0, 1 # Advance json_str_buffer pointer
    addi t2, t2, 1 # Increment length counter
    j parse_digit_loop

end_of_number_str:
    # Null-terminate the number string in number_buffer
    li t0, 0
    sb t0, 0(t1)

    # Convert to integer using atoi
    mv a0, s10 # Pass address of number_buffer to atoi
    jal ra, atoi # Result in a0

    # TODO: Clamp a0 to 8-bit signed (-128 to 127)
    # For now, direct store assuming values are already in range
    # sb a0, 0(s1)   # Store the byte weight
    # Proper clamping:
    li t0, 127      # max value
    li t1, -128     # min value
    blt a0, t1, clamp_min # if a0 < -128, clamp to -128
    bgt a0, t0, clamp_max # if a0 > 127, clamp to 127
    j store_weight

clamp_min:
    mv a0, t1
    j store_weight
clamp_max:
    mv a0, t0
    # Fall through to store_weight

store_weight:
    sb a0, 0(s1)    # Store the clamped byte weight into all_weights_buffer
    addi s1, s1, 1  # Increment all_weights_buffer pointer

    addi s9, s9, 1  # Increment weight_loop_counter

    # Skip characters until next number (comma) or end of list (']')
skip_to_next_char_in_list:
    lb t0, 0(s0)
    beq t0, zero, parsing_error_unexpected_end
    li t1, ','
    beq t0, t1, found_comma_in_list
    li t1, ']'
    beq t0, t1, found_end_bracket_in_list # End of current neuron's weights or end of matrix
    # Skip other characters like spaces
    addi s0, s0, 1
    j skip_to_next_char_in_list

found_comma_in_list:
    addi s0, s0, 1 # Move past comma
    j parse_weight_loop # Look for next weight for this neuron

found_end_bracket_in_list: # Found ']'
    # This ']' could be the end of a neuron's weight list, or end of the entire layer's matrix
    # Handled by neuron_done or layer_done logic
    j parse_weight_loop # Let the loop condition (s9 vs s7) decide if neuron is done

neuron_done: # Finished all weights for the current neuron s8
    # Expect ']' after a neuron's weights.
skip_past_row_end_bracket:
    lb t0, 0(s0)
    beq t0, zero, parsing_error_unexpected_end
    li t1, ']'
    beq t0, t1, increment_neuron_counter
    # Skip other chars like spaces, expecting ']'
    addi s0, s0, 1
    j skip_past_row_end_bracket

increment_neuron_counter:
    addi s0, s0, 1 # Move past ']' of the neuron's weight list
    addi s8, s8, 1 # Increment neuron_loop_counter

    # After a row "]", there might be a comma then a new row "[", or "]]" for end of matrix.
skip_to_next_row_or_matrix_end:
    lb t0, 0(s0)
    beq t0, zero, parsing_error_unexpected_end
    li t1, ',' # Comma before next neuron's weights "[...]"
    beq t0, t1, prep_next_row
    li t1, ']' # End of matrix "]]"
    beq t0, t1, check_if_layer_really_done # Let the main neuron loop (s8 vs s6) decide if layer is done
    addi s0, s0, 1
    j skip_to_next_row_or_matrix_end

prep_next_row:
    addi s0, s0, 1 # Move past comma
    j parse_neuron_weights_loop # Start next neuron (row)

check_if_layer_really_done:
    # We encountered a ']' which could be the end of the matrix.
    # The loop condition s8 == s6 in parse_neuron_weights_loop will handle this.
    j parse_neuron_weights_loop

layer_done: # Finished all neurons for the current layer s5
    # Expect ']]' for the end of the layer's matrix. One ']' was consumed by neuron_done.
skip_past_matrix_end_bracket:
    lb t0, 0(s0)
    beq t0, zero, parsing_error_unexpected_end
    li t1, ']'
    beq t0, t1, increment_layer_counter
    # Skip other chars, expecting ']'
    addi s0, s0, 1
    j skip_past_matrix_end_bracket

increment_layer_counter:
    addi s0, s0, 1 # Move past the second ']' of the matrix
    addi s5, s5, 1 # Increment current_layer_index

    # Store pointer to the start of the *next* layer's weights
    # Only if we are not past the number of weight matrices
    bge s5, s2, parsing_done # If new s5 equals total weight matrices, all pointers stored

    sw s1, 0(s3)   # s1 is already pointing to where the next layer's weights will start
    addi s3, s3, 4 # Advance pointer for l_weights_ptr_array

    # Skip characters until the start of the next layer's definition or end of JSON '}'
    # e.g., skip ',"l<next_layer_num>":[['
skip_to_next_layer_def:
    lb t0, 0(s0)
    beq t0, zero, parsing_done # If string ends, and we expected more layers, it's an error handled by main loop condition
    li t1, '{' # Could be end of JSON '}' if this was the last layer.
    beq t0, t1, parsing_error_unexpected_char # Should be '}' only at very end
    li t1, '}'
    beq t0, t1, parsing_done # If it's the end of the JSON object.

    # Look for '[' which would be part of the next layer's "[[".
    # This implicitly skips ',"l<n>":'
    li t1, '['
    beq t0, t1, found_next_layer_matrix_start
    addi s0, s0, 1
    j skip_to_next_layer_def

found_next_layer_matrix_start:
    # s0 is at the first '[' of "[[". The logic at 'skip_to_matrix_start' handles this.
    j parse_next_layer_weights

parsing_done:
    # Restore callee-saved registers and return
    lw ra, 60(sp)
    lw s0, 56(sp)
    lw s1, 52(sp)
    lw s2, 48(sp) # Restore original s2 (N_arch_layers from argument)
    lw s3, 44(sp)
    lw s4, 40(sp)
    lw s5, 36(sp)
    lw s6, 32(sp)
    lw s7, 28(sp)
    lw s8, 24(sp)
    lw s9, 20(sp)
    lw s10, 16(sp)
    addi sp, sp, 64
    ret

parsing_error_unexpected_end:
    # Simple error handling: print a message and hang, or exit.
    # For now, just jump to a point that effectively stops or returns.
    # Or, set a specific error code in a0. For now, go to parsing_done.
    j parsing_done # Or a dedicated error exit

parsing_error_expected_bracket:
    j parsing_done

parsing_error_num_too_long:
    j parsing_done

parsing_error_unexpected_char:
    j parsing_done

# End of parse_weights_json
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# read_input_activations: Reads the input flower data string, parses up to 4 integers,
#                         clamps them to 8-bit signed, and stores them as bytes.
# Arguments:
#   a0: Pointer to input_str_buffer
#   a1: Pointer to input_activations_array (byte array)
#   a2: Pointer to number_buffer (general purpose for atoi)
# Output:
#   input_activations_array populated with up to 4 bytes.
#   Returns number of activations read in t0 (for debugging or validation, optional)
# Registers used:
#   s0: Pointer to current position in input_str_buffer
#   s1: Pointer to current position in input_activations_array
#   s2: Pointer to number_buffer (for atoi conversion)
#   s3: Counter for numbers read (max 4)
#   t0, t1, t2, t3, t4, t5: Temporary registers
#-------------------------------------------------------------------------------
read_input_activations:
    addi sp, sp, -28
    sw ra, 24(sp)
    sw s0, 20(sp) # input_str_buffer_ptr
    sw s1, 16(sp) # input_activations_array_ptr
    sw s2, 12(sp) # number_buffer_ptr
    sw s3, 8(sp)  # numbers_read_count

    mv s0, a0     # s0 = &input_str_buffer
    mv s1, a1     # s1 = &input_activations_array
    mv s2, a2     # s2 = &number_buffer (passed as arg, usually la s2, number_buffer)

    # Get the input activations string
    # Re-using a0, a1 for gets call
    # The caller of read_input_activations should ensure a0 points to input_str_buffer
    li a1, 50     # Max length for input_str_buffer
    jal ra, gets  # String is now in input_str_buffer (s0)

    li s3, 0      # numbers_read_count = 0
    mv t4, s2     # t4 = current write pointer for number_buffer_local (start of number_buffer)
                  # s2 holds the base address of number_buffer. t4 is the moving pointer.

parse_input_loop:
    lb t0, 0(s0)  # t0 = input_str_buffer[i]

    # Check for terminators (null, newline) or separator (comma)
    beq t0, zero, process_input_number_and_maybe_end
    li t1, '\n'
    beq t0, t1, process_input_number_and_maybe_end
    li t1, ','
    beq t0, t1, process_input_number_and_continue

    # Check if t0 is a digit or leading minus for the number
    li t1, '0'
    li t2, '9'
    blt t0, t1, check_input_char_is_minus
    bgt t0, t2, input_char_not_valid_or_end # Not a digit
    # It's a digit
    j copy_input_digit_to_buffer

check_input_char_is_minus:
    li t1, '-'
    beq t0, t1, copy_input_digit_to_buffer # It's a minus
    # Any other char that is not digit, not minus, not separator/terminator
    j input_char_not_valid_or_end

copy_input_digit_to_buffer:
    # TODO: Check for number_buffer overflow (e.g. >11 chars for a 32-bit int string)
    sb t0, 0(t4)    # number_buffer_local[j] = t0
    addi t4, t4, 1  # j++
    addi s0, s0, 1  # i++
    j parse_input_loop

input_char_not_valid_or_end: # E.g. unexpected char, or just end of current number part
    # If we have digits in number_buffer_local (t4 > s2), process them.
    # Otherwise, could be error or multiple separators. For simplicity, assume valid formatting.
    beq t4, s2, skip_processing_if_buffer_empty # If t4 is still at start of number_buffer, nothing to parse
    # Fall through to process the number if buffer has content

process_input_number_and_maybe_end: # Called on null or newline
    # If buffer is empty (e.g. "1,2," or empty input), and we hit end, don't process.
    beq t4, s2, end_read_input_loop_direct
    # Fall through to process number logic. This label implies end of string AFTER a number.

process_input_number_and_continue: # Called on comma, or fallthrough from above for terminators
    # Terminate number_buffer_local with null
    li t1, 0
    sb t1, 0(t4) # Null-terminate current number string in number_buffer

    # Convert number_buffer to integer using atoi
    mv a0, s2     # Pass address of number_buffer (s2) to atoi
    jal ra, atoi  # Result is in a0 (original integer)

    # Clamp a0 to 8-bit signed (-128 to 127)
    li t0, 127    # max value
    li t1, -128   # min value
    blt a0, t1, clamp_input_min
    bgt a0, t0, clamp_input_max
    j store_input_activation # Value is already in range

clamp_input_min:
    mv a0, t1
    j store_input_activation
clamp_input_max:
    mv a0, t0
    # Fall through to store_input_activation

store_input_activation:
    sb a0, 0(s1)    # Store the clamped byte into input_activations_array
    addi s1, s1, 1  # Increment input_activations_array pointer (byte-wise)
    addi s3, s3, 1  # Increment numbers_read_count

    # Reset number_buffer_local pointer
    mv t4, s2       # Reset t4 to start of number_buffer

    # Check if 4 numbers have been read or if it was end of string
    li t0, 4
    beq s3, t0, end_read_input_loop_direct # Max 4 numbers read

    lb t0, 0(s0)    # Current char that caused processing (could be ',', '\n', or '\0')
    beq t0, zero, end_read_input_loop_direct # If it was null, end.
    li t1, '\n'
    beq t0, t1, end_read_input_loop_direct # If it was newline, end.

    # If it was a comma, we need to advance s0 and continue parsing
    li t1, ','
    beq t0, t1, advance_input_and_continue

    # If not comma and not terminator, but less than 4 numbers read (e.g. "1 2") - treat as end for simplicity.
    j end_read_input_loop_direct

skip_processing_if_buffer_empty:
    # If we hit a separator/terminator and number buffer is empty (e.g. ",," or leading ",")
    lb t0, 0(s0)
    beq t0, zero, end_read_input_loop_direct # If end of string, finish
    li t1, '\n'
    beq t0, t1, end_read_input_loop_direct # If newline, finish
    # If it was a comma, skip it and continue looking for next number
    li t1, ','
    beq t0, t1, advance_input_and_continue
    # Otherwise, it's an unexpected char, or just the end.
    j end_read_input_loop_direct


advance_input_and_continue:
    addi s0, s0, 1  # Move past the comma
    j parse_input_loop

end_read_input_loop_direct:
    mv t0, s3       # Store numbers_read_count in t0 as a potential return value (optional)

    lw ra, 24(sp)
    lw s0, 20(sp)
    lw s1, 16(sp)
    lw s2, 12(sp)
    lw s3, 8(sp)
    addi sp, sp, 28
    ret

# End of read_input_activations
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# matrix_vector_mult_relu: Performs matrix-vector multiplication, applies ReLU,
#                          clamps to 8-bit (0-127), and stores the output activations.
# Arguments:
#   a0: Pointer to prev_layer_activations (byte array)
#   a1: Pointer to current_layer_weights (byte matrix, row-major)
#   a2: num_neurons_prev_layer (N_prev)
#   a3: num_neurons_current_layer (N_curr)
#   a4: Pointer to output_activations buffer (byte array)
#
# Registers used (callee-saved):
#   s0: loop counter for current layer neurons (i, from 0 to N_curr-1)
#   s1: loop counter for prev layer neurons (j, from 0 to N_prev-1)
#   s2: accumulator (Z_i), 32-bit for sum of products
#   s3: pointer to prev_layer_activations
#   s4: pointer to current_layer_weights
#   s5: pointer to output_activations
#   s6: num_neurons_prev_layer (N_prev)
#   s7: num_neurons_current_layer (N_curr)
#   s8: base address for current row of weights (current_layer_weights_ptr + (i * N_prev))
# Registers used (caller-saved / temporary):
#   t0, t1, t2, t3, t4, t5, t6
#-------------------------------------------------------------------------------
matrix_vector_mult_relu:
    addi sp, sp, -48 # Save RA and 8 s-registers (s0-s8)
    sw ra, 44(sp)
    sw s0, 40(sp) # i
    sw s1, 36(sp) # j
    sw s2, 32(sp) # accumulator Z_i
    sw s3, 28(sp) # prev_layer_activations_ptr
    sw s4, 24(sp) # current_layer_weights_ptr
    sw s5, 20(sp) # output_activations_ptr
    sw s6, 16(sp) # N_prev
    sw s7, 12(sp) # N_curr
    sw s8, 8(sp)  # base_weight_row_ptr

    # Move arguments to s-registers
    mv s3, a0  # prev_layer_activations_ptr
    mv s4, a1  # current_layer_weights_ptr
    mv s6, a2  # N_prev
    mv s7, a3  # N_curr
    mv s5, a4  # output_activations_ptr

    li s0, 0   # i = 0 (current layer neuron index)

outer_loop: # Loop through each neuron in the current layer
    beq s0, s7, end_outer_loop # if i == N_curr, exit loop

    li s2, 0   # Z_i = 0 (accumulator for neuron i)
    li s1, 0   # j = 0 (previous layer neuron index)

    # Calculate base address for the current row in the weight matrix
    # base_weight_row_ptr = current_layer_weights_ptr + (i * N_prev)
    mul t0, s0, s6 # t0 = i * N_prev
    add s8, s4, t0 # s8 = base_weight_row_ptr

inner_loop: # Loop through each neuron in the previous layer (for dot product)
    beq s1, s6, end_inner_loop # if j == N_prev, exit inner loop

    # Load weight W_ij (byte)
    add t0, s8, s1 # t0 = address of W_ij = base_weight_row_ptr + j
    lb t1, 0(t0)   # t1 = W_ij (byte, sign-extended by lb)

    # Load activation a_j (byte)
    add t0, s3, s1 # t0 = address of a_j = prev_layer_activations_ptr + j
    lb t2, 0(t0)   # t2 = a_j (byte, sign-extended by lb)

    # Product: W_ij * a_j
    mul t3, t1, t2 # t3 = product (32-bit)

    # Accumulate
    add s2, s2, t3 # Z_i = Z_i + product

    addi s1, s1, 1 # j++
    j inner_loop

end_inner_loop:
    # Z_i (sum of products for neuron i) is in s2

    # Apply ReLU: if Z_i < 0, Z_i = 0
    bltz s2, relu_set_zero
    j relu_done
relu_set_zero:
    li s2, 0
relu_done:

    # Clamp to 8-bit positive range (0-127, since ReLU makes it >=0)
    li t0, 127
    bgt s2, t0, clamp_set_max
    j clamp_done
clamp_set_max:
    mv s2, t0 # Z_i = 127
clamp_done:
    # s2 now holds the final 8-bit clamped activation for neuron i

    # Store result in output_activations_ptr + i
    add t0, s5, s0 # t0 = output_activations_ptr + i
    sb s2, 0(t0)   # Store the byte activation

    addi s0, s0, 1 # i++
    j outer_loop

end_outer_loop:
    # Restore registers and return
    lw ra, 44(sp)
    lw s0, 40(sp)
    lw s1, 36(sp)
    lw s2, 32(sp)
    lw s3, 28(sp)
    lw s4, 24(sp)
    lw s5, 20(sp)
    lw s6, 16(sp)
    lw s7, 12(sp)
    lw s8, 8(sp)
    addi sp, sp, 48
    ret

# End of matrix_vector_mult_relu
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# argmax: Finds the index of the maximum value in a byte array.
# Arguments:
#   a0: Pointer to final_activations_ptr (byte array)
#   a1: num_output_neurons
# Returns:
#   a0: Index of the maximum value
# Registers used (callee-saved):
#   s0: max_value (byte, but stored in full register, sign-extended if necessary)
#   s1: max_index
#   s2: loop counter (i)
#   s3: pointer to final_activations_ptr
#   s4: num_output_neurons
# Registers used (caller-saved / temporary):
#   t0, t1
#-------------------------------------------------------------------------------
argmax:
    addi sp, sp, -28 # Save RA and s0-s4
    sw ra, 24(sp)
    sw s0, 20(sp) # max_value
    sw s1, 16(sp) # max_index
    sw s2, 12(sp) # i (loop counter)
    sw s3, 8(sp)  # final_activations_ptr
    sw s4, 4(sp)  # num_output_neurons

    mv s3, a0     # s3 = final_activations_ptr
    mv s4, a1     # s4 = num_output_neurons

    # Handle edge case: if num_output_neurons is 0 or negative, return 0 or error.
    # For simplicity, assume num_output_neurons >= 1 based on problem constraints.
    # If num_output_neurons == 0, this code would try to read from final_activations_ptr[0]
    # which might be invalid. A robust implementation would check s4 here.
    # Example check: blez s4, argmax_return_error (or return 0 as index)

    # Initialize max_value with the first element and max_index with 0
    lb s0, 0(s3)  # s0 = final_activations_ptr[0] (lb sign-extends the byte)
    li s1, 0      # s1 = max_index = 0

    # Loop from i = 1 up to num_output_neurons - 1
    li s2, 1      # s2 = i = 1

argmax_loop:
    beq s2, s4, end_argmax_loop # if i == num_output_neurons, exit loop

    # Load current_value = final_activations_ptr[i]
    add t0, s3, s2 # t0 = final_activations_ptr + i
    lb t1, 0(t0)   # t1 = current_value (byte, sign-extended)

    # Compare current_value with max_value
    # if t1 <= s0, continue loop
    ble t1, s0, argmax_continue_loop

    # else (current_value > max_value), update max_value and max_index
    mv s0, t1      # max_value = current_value
    mv s1, s2      # max_index = i

argmax_continue_loop:
    addi s2, s2, 1 # i++
    j argmax_loop

end_argmax_loop:
    mv a0, s1      # Move max_index to a0 for return

    lw ra, 24(sp)
    lw s0, 20(sp)
    lw s1, 16(sp)
    lw s2, 12(sp)
    lw s3, 8(sp)
    lw s4, 4(sp)
    addi sp, sp, 28
    ret

# argmax_return_error: (Optional error handling for num_output_neurons <= 0)
#   li a0, -1 # Or some other error indicator
#   j end_argmax_loop_no_return_val_change # (Need another label to skip mv a0,s1)

# End of argmax
#-------------------------------------------------------------------------------
