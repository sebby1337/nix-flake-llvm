target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

@global_counter = global i32 0, align 4
@array = global [10 x i32] zeroinitializer, align 16

define i32 @compute_sum(i32 %n) {
entry:
  %sum = alloca i32
  store i32 0, i32* %sum
  %i = alloca i32 
  store i32 0, i32* %i
  br label %loop_header

loop_header:
  %i.val = load i32, i32* %i
  %cmp = icmp slt i32 %i.val, %n
  br i1 %cmp, label %loop_body, label %exit

loop_body:
  %curr_sum = load i32, i32* %sum
  %i.val2 = load i32, i32* %i
  %elem_ptr = getelementptr [10 x i32], [10 x i32]* @array, i32 0, i32 %i.val2
  %elem = load i32, i32* %elem_ptr
  %new_sum = add i32 %curr_sum, %elem
  store i32 %new_sum, i32* %sum
  %i.next = add i32 %i.val2, 1
  store i32 %i.next, i32* %i
  br label %loop_header

exit:
  %result = load i32, i32* %sum
  ret i32 %result
}

define i32 @complex_computation(i32 %x, i32 %y) {
entry:
  %result = alloca i32
  store i32 0, i32* %result
  br label %loop

loop:
  %i = phi i32 [ 0, %entry ], [ %i.next, %loop ]
  %val1 = mul i32 %x, %y    ; Invariant computation
  %val2 = mul i32 %val1, %i ; Partially invariant
  %curr = load i32, i32* %result
  %new = add i32 %curr, %val2
  store i32 %new, i32* %result
  %i.next = add i32 %i, 1
  %cond = icmp slt i32 %i.next, 10
  br i1 %cond, label %loop, label %exit

exit:
  %final = load i32, i32* %result
  ret i32 %final
}

define i32 @helper(i32 %x) {
  %result = mul i32 %x, 42
  ret i32 %result
}

define i32 @dead_code_example(i32 %input) {
entry:
  %unused = add i32 %input, 10  ; Dead computation
  %used = mul i32 %input, 2
  %dead_branch_cond = icmp eq i32 %input, 999999
  br i1 %dead_branch_cond, label %never_taken, label %main_path

never_taken:                                       ; Dead block
  %dead_compute = add i32 %unused, 50
  br label %exit

main_path:
  %result = call i32 @helper(i32 %used)
  br label %exit

exit:
  %final = phi i32 [ %dead_compute, %never_taken ], [ %result, %main_path ]
  ret i32 %final
}

define i32 @main() {
  ; Initialize array with some values
  %arr_ptr = getelementptr [10 x i32], [10 x i32]* @array, i32 0, i32 0
  store i32 1, i32* %arr_ptr
  %arr_ptr1 = getelementptr [10 x i32], [10 x i32]* @array, i32 0, i32 1
  store i32 2, i32* %arr_ptr1

  %sum = call i32 @compute_sum(i32 10)
  %comp = call i32 @complex_computation(i32 %sum, i32 5)
  %final = call i32 @dead_code_example(i32 %comp)
  
  ret i32 %final
}
