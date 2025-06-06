; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt -S -passes=licm -use-dereferenceable-at-point-semantics=false < %s | FileCheck %s
; RUN: opt -S -passes=licm -use-dereferenceable-at-point-semantics < %s | FileCheck %s

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare void @unknown()
declare void @init(ptr nocapture)
declare void @use(i8)

define i8 @test_sink_alloca() {
; CHECK-LABEL: @test_sink_alloca(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[A:%.*]] = alloca [32 x i8], align 1
; CHECK-NEXT:    call void @init(ptr [[A]])
; CHECK-NEXT:    br label [[FOR_BODY:%.*]]
; CHECK:       for.body:
; CHECK-NEXT:    [[IV:%.*]] = phi i64 [ [[IV_NEXT:%.*]], [[FOR_BODY]] ], [ 0, [[ENTRY:%.*]] ]
; CHECK-NEXT:    call void @unknown()
; CHECK-NEXT:    [[IV_NEXT]] = add nuw nsw i64 [[IV]], 1
; CHECK-NEXT:    [[EXITCOND:%.*]] = icmp eq i64 [[IV_NEXT]], 200
; CHECK-NEXT:    br i1 [[EXITCOND]], label [[FOR_END:%.*]], label [[FOR_BODY]]
; CHECK:       for.end:
; CHECK-NEXT:    [[ADDR_LE:%.*]] = getelementptr i8, ptr [[A]], i32 31
; CHECK-NEXT:    [[RES_LE:%.*]] = load i8, ptr [[ADDR_LE]], align 1
; CHECK-NEXT:    ret i8 [[RES_LE]]
;
entry:
  %a = alloca [32 x i8]
  call void @init(ptr %a)
  br label %for.body

for.body:
  %iv = phi i64 [ %iv.next, %for.body ], [ 0, %entry ]
  call void @unknown() ;; may throw
  %addr = getelementptr i8, ptr %a, i32 31
  %res = load i8, ptr %addr
  %iv.next = add nuw nsw i64 %iv, 1
  %exitcond = icmp eq i64 %iv.next, 200
  br i1 %exitcond, label %for.end, label %for.body

for.end:
  ret i8 %res
}

define i8 @test_hoist_alloca() {
; CHECK-LABEL: @test_hoist_alloca(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[A:%.*]] = alloca [32 x i8], align 1
; CHECK-NEXT:    call void @init(ptr [[A]])
; CHECK-NEXT:    [[ADDR:%.*]] = getelementptr i8, ptr [[A]], i32 31
; CHECK-NEXT:    [[RES:%.*]] = load i8, ptr [[ADDR]], align 1
; CHECK-NEXT:    br label [[FOR_BODY:%.*]]
; CHECK:       for.body:
; CHECK-NEXT:    [[IV:%.*]] = phi i64 [ [[IV_NEXT:%.*]], [[FOR_BODY]] ], [ 0, [[ENTRY:%.*]] ]
; CHECK-NEXT:    call void @unknown()
; CHECK-NEXT:    call void @use(i8 [[RES]])
; CHECK-NEXT:    [[IV_NEXT]] = add nuw nsw i64 [[IV]], 1
; CHECK-NEXT:    [[EXITCOND:%.*]] = icmp eq i64 [[IV_NEXT]], 200
; CHECK-NEXT:    br i1 [[EXITCOND]], label [[FOR_END:%.*]], label [[FOR_BODY]]
; CHECK:       for.end:
; CHECK-NEXT:    [[RES_LCSSA:%.*]] = phi i8 [ [[RES]], [[FOR_BODY]] ]
; CHECK-NEXT:    ret i8 [[RES_LCSSA]]
;
entry:
  %a = alloca [32 x i8]
  call void @init(ptr %a)
  br label %for.body

for.body:
  %iv = phi i64 [ %iv.next, %for.body ], [ 0, %entry ]
  call void @unknown() ;; may throw
  %addr = getelementptr i8, ptr %a, i32 31
  %res = load i8, ptr %addr
  call void @use(i8 %res)
  %iv.next = add nuw nsw i64 %iv, 1
  %exitcond = icmp eq i64 %iv.next, 200
  br i1 %exitcond, label %for.end, label %for.body

for.end:
  ret i8 %res
}

; The attributes listed here are a) inferred by -O3 from the names
; and b) required for a standalone test.  We're very inconsistent about
; which decisions we drive from TLI vs assume attributes have been infered.
declare void @free(ptr nocapture)
declare noalias ptr @malloc(i64)

define i8 @test_sink_malloc() {
; CHECK-LABEL: @test_sink_malloc(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[A_RAW:%.*]] = call nonnull ptr @malloc(i64 32)
; CHECK-NEXT:    call void @init(ptr [[A_RAW]])
; CHECK-NEXT:    br label [[FOR_BODY:%.*]]
; CHECK:       for.body:
; CHECK-NEXT:    [[IV:%.*]] = phi i64 [ [[IV_NEXT:%.*]], [[FOR_BODY]] ], [ 0, [[ENTRY:%.*]] ]
; CHECK-NEXT:    call void @unknown()
; CHECK-NEXT:    [[IV_NEXT]] = add nuw nsw i64 [[IV]], 1
; CHECK-NEXT:    [[EXITCOND:%.*]] = icmp eq i64 [[IV_NEXT]], 200
; CHECK-NEXT:    br i1 [[EXITCOND]], label [[FOR_END:%.*]], label [[FOR_BODY]]
; CHECK:       for.end:
; CHECK-NEXT:    [[ADDR_LE:%.*]] = getelementptr i8, ptr [[A_RAW]], i32 31
; CHECK-NEXT:    [[RES_LE:%.*]] = load i8, ptr [[ADDR_LE]], align 1
; CHECK-NEXT:    call void @free(ptr [[A_RAW]])
; CHECK-NEXT:    ret i8 [[RES_LE]]
;
entry:
  ; Mark as nonnull to simplify test
  %a.raw = call nonnull ptr @malloc(i64 32)
  call void @init(ptr %a.raw)
  br label %for.body

for.body:
  %iv = phi i64 [ %iv.next, %for.body ], [ 0, %entry ]
  call void @unknown() ;; may throw
  %addr = getelementptr i8, ptr %a.raw, i32 31
  %res = load i8, ptr %addr
  %iv.next = add nuw nsw i64 %iv, 1
  %exitcond = icmp eq i64 %iv.next, 200
  br i1 %exitcond, label %for.end, label %for.body

for.end:
  call void @free(ptr %a.raw)
  ret i8 %res
}

; TODO: We can hoist the load in this case, but only once we have
; some form of context sensitive free analysis.
define i8 @test_hoist_malloc() {
; CHECK-LABEL: @test_hoist_malloc(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[A_RAW:%.*]] = call nonnull ptr @malloc(i64 32)
; CHECK-NEXT:    call void @init(ptr [[A_RAW]])
; CHECK-NEXT:    [[ADDR:%.*]] = getelementptr i8, ptr [[A_RAW]], i32 31
; CHECK-NEXT:    br label [[FOR_BODY:%.*]]
; CHECK:       for.body:
; CHECK-NEXT:    [[IV:%.*]] = phi i64 [ [[IV_NEXT:%.*]], [[FOR_BODY]] ], [ 0, [[ENTRY:%.*]] ]
; CHECK-NEXT:    call void @unknown()
; CHECK-NEXT:    [[RES:%.*]] = load i8, ptr [[ADDR]], align 1
; CHECK-NEXT:    call void @use(i8 [[RES]])
; CHECK-NEXT:    [[IV_NEXT]] = add nuw nsw i64 [[IV]], 1
; CHECK-NEXT:    [[EXITCOND:%.*]] = icmp eq i64 [[IV_NEXT]], 200
; CHECK-NEXT:    br i1 [[EXITCOND]], label [[FOR_END:%.*]], label [[FOR_BODY]]
; CHECK:       for.end:
; CHECK-NEXT:    [[RES_LCSSA:%.*]] = phi i8 [ [[RES]], [[FOR_BODY]] ]
; CHECK-NEXT:    call void @free(ptr [[A_RAW]])
; CHECK-NEXT:    ret i8 [[RES_LCSSA]]
;
entry:
  %a.raw = call nonnull ptr @malloc(i64 32)
  call void @init(ptr %a.raw)
  br label %for.body

for.body:
  %iv = phi i64 [ %iv.next, %for.body ], [ 0, %entry ]
  call void @unknown() ;; may throw
  %addr = getelementptr i8, ptr %a.raw, i32 31
  %res = load i8, ptr %addr
  call void @use(i8 %res)
  %iv.next = add nuw nsw i64 %iv, 1
  %exitcond = icmp eq i64 %iv.next, 200
  br i1 %exitcond, label %for.end, label %for.body

for.end:
  call void @free(ptr %a.raw)
  ret i8 %res
}

define i8 @test_hoist_malloc_leak() nofree nosync {
; CHECK-LABEL: @test_hoist_malloc_leak(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[A_RAW:%.*]] = call nonnull ptr @malloc(i64 32)
; CHECK-NEXT:    call void @init(ptr [[A_RAW]])
; CHECK-NEXT:    [[ADDR:%.*]] = getelementptr i8, ptr [[A_RAW]], i32 31
; CHECK-NEXT:    br label [[FOR_BODY:%.*]]
; CHECK:       for.body:
; CHECK-NEXT:    [[IV:%.*]] = phi i64 [ [[IV_NEXT:%.*]], [[FOR_BODY]] ], [ 0, [[ENTRY:%.*]] ]
; CHECK-NEXT:    call void @unknown()
; CHECK-NEXT:    [[RES:%.*]] = load i8, ptr [[ADDR]], align 1
; CHECK-NEXT:    call void @use(i8 [[RES]])
; CHECK-NEXT:    [[IV_NEXT]] = add nuw nsw i64 [[IV]], 1
; CHECK-NEXT:    [[EXITCOND:%.*]] = icmp eq i64 [[IV_NEXT]], 200
; CHECK-NEXT:    br i1 [[EXITCOND]], label [[FOR_END:%.*]], label [[FOR_BODY]]
; CHECK:       for.end:
; CHECK-NEXT:    [[RES_LCSSA:%.*]] = phi i8 [ [[RES]], [[FOR_BODY]] ]
; CHECK-NEXT:    ret i8 [[RES_LCSSA]]
;
entry:
  %a.raw = call nonnull ptr @malloc(i64 32)
  call void @init(ptr %a.raw)
  br label %for.body

for.body:
  %iv = phi i64 [ %iv.next, %for.body ], [ 0, %entry ]
  call void @unknown() ;; may throw
  %addr = getelementptr i8, ptr %a.raw, i32 31
  %res = load i8, ptr %addr
  call void @use(i8 %res)
  %iv.next = add nuw nsw i64 %iv, 1
  %exitcond = icmp eq i64 %iv.next, 200
  br i1 %exitcond, label %for.end, label %for.body

for.end:
  ret i8 %res
}

; In this case, we can't hoist the load out of the loop as the memory it
; accesses may have been conditionally freed in a manner correlated with
; whether the load is reached in the loop.
define void @test_hoist_malloc_cond_free(i1 %c) {
; CHECK-LABEL: @test_hoist_malloc_cond_free(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[A_RAW:%.*]] = call nonnull ptr @malloc(i64 32)
; CHECK-NEXT:    call void @init(ptr [[A_RAW]])
; CHECK-NEXT:    br i1 [[C:%.*]], label [[COND_FREE:%.*]], label [[PREHEADER:%.*]]
; CHECK:       cond.free:
; CHECK-NEXT:    call void @free(ptr [[A_RAW]])
; CHECK-NEXT:    br label [[PREHEADER]]
; CHECK:       preheader:
; CHECK-NEXT:    [[ADDR:%.*]] = getelementptr i8, ptr [[A_RAW]], i32 31
; CHECK-NEXT:    br label [[FOR_BODY:%.*]]
; CHECK:       for.body:
; CHECK-NEXT:    [[IV:%.*]] = phi i64 [ [[IV_NEXT:%.*]], [[LOOP_LATCH:%.*]] ], [ 0, [[PREHEADER]] ]
; CHECK-NEXT:    br i1 [[C]], label [[FOR_END:%.*]], label [[LOOP_LATCH]]
; CHECK:       loop.latch:
; CHECK-NEXT:    call void @unknown()
; CHECK-NEXT:    [[RES:%.*]] = load i8, ptr [[ADDR]], align 1
; CHECK-NEXT:    call void @use(i8 [[RES]])
; CHECK-NEXT:    [[IV_NEXT]] = add nuw nsw i64 [[IV]], 1
; CHECK-NEXT:    [[EXITCOND:%.*]] = icmp eq i64 [[IV_NEXT]], 200
; CHECK-NEXT:    br i1 [[EXITCOND]], label [[FOR_END]], label [[FOR_BODY]]
; CHECK:       for.end:
; CHECK-NEXT:    ret void
;
entry:
  %a.raw = call nonnull ptr @malloc(i64 32)
  call void @init(ptr %a.raw)
  br i1 %c, label %cond.free, label %preheader
cond.free:
  call void @free(ptr %a.raw)
  br label %preheader
preheader:
  br label %for.body

for.body:
  %iv = phi i64 [ %iv.next, %loop.latch ], [ 0, %preheader ]
  br i1 %c, label %for.end, label %loop.latch

loop.latch:
  call void @unknown() ;; may throw
  %addr = getelementptr i8, ptr %a.raw, i32 31
  %res = load i8, ptr %addr
  call void @use(i8 %res)
  %iv.next = add nuw nsw i64 %iv, 1
  %exitcond = icmp eq i64 %iv.next, 200
  br i1 %exitcond, label %for.end, label %for.body

for.end:
  ret void
}

define i8 @test_sink_malloc_cond_free(i1 %c) {
; CHECK-LABEL: @test_sink_malloc_cond_free(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[A_RAW:%.*]] = call nonnull ptr @malloc(i64 32)
; CHECK-NEXT:    call void @init(ptr [[A_RAW]])
; CHECK-NEXT:    br i1 [[C:%.*]], label [[COND_FREE:%.*]], label [[PREHEADER:%.*]]
; CHECK:       cond.free:
; CHECK-NEXT:    call void @free(ptr [[A_RAW]])
; CHECK-NEXT:    br label [[PREHEADER]]
; CHECK:       preheader:
; CHECK-NEXT:    br label [[FOR_BODY:%.*]]
; CHECK:       for.body:
; CHECK-NEXT:    [[IV:%.*]] = phi i64 [ [[IV_NEXT:%.*]], [[LOOP_LATCH:%.*]] ], [ 0, [[PREHEADER]] ]
; CHECK-NEXT:    br i1 [[C]], label [[FOR_END_SPLIT_LOOP_EXIT1:%.*]], label [[LOOP_LATCH]]
; CHECK:       loop.latch:
; CHECK-NEXT:    call void @unknown()
; CHECK-NEXT:    [[IV_NEXT]] = add nuw nsw i64 [[IV]], 1
; CHECK-NEXT:    [[EXITCOND:%.*]] = icmp eq i64 [[IV_NEXT]], 200
; CHECK-NEXT:    br i1 [[EXITCOND]], label [[FOR_END_SPLIT_LOOP_EXIT:%.*]], label [[FOR_BODY]]
; CHECK:       for.end.split.loop.exit:
; CHECK-NEXT:    [[ADDR_LE:%.*]] = getelementptr i8, ptr [[A_RAW]], i32 31
; CHECK-NEXT:    [[RES_LE:%.*]] = load i8, ptr [[ADDR_LE]], align 1
; CHECK-NEXT:    br label [[FOR_END:%.*]]
; CHECK:       for.end.split.loop.exit1:
; CHECK-NEXT:    [[PHI_PH2:%.*]] = phi i8 [ 0, [[FOR_BODY]] ]
; CHECK-NEXT:    br label [[FOR_END]]
; CHECK:       for.end:
; CHECK-NEXT:    [[PHI:%.*]] = phi i8 [ [[RES_LE]], [[FOR_END_SPLIT_LOOP_EXIT]] ], [ [[PHI_PH2]], [[FOR_END_SPLIT_LOOP_EXIT1]] ]
; CHECK-NEXT:    ret i8 [[PHI]]
;
entry:
  %a.raw = call nonnull ptr @malloc(i64 32)
  call void @init(ptr %a.raw)
  br i1 %c, label %cond.free, label %preheader
cond.free:
  call void @free(ptr %a.raw)
  br label %preheader
preheader:
  br label %for.body

for.body:
  %iv = phi i64 [ %iv.next, %loop.latch ], [ 0, %preheader ]
  br i1 %c, label %for.end, label %loop.latch

loop.latch:
  call void @unknown() ;; may throw
  %addr = getelementptr i8, ptr %a.raw, i32 31
  %res = load i8, ptr %addr
  %iv.next = add nuw nsw i64 %iv, 1
  %exitcond = icmp eq i64 %iv.next, 200
  br i1 %exitcond, label %for.end, label %for.body

for.end:
  %phi = phi i8 [%res, %loop.latch], [0, %for.body]
  ret i8 %phi
}

declare noalias ptr @my_alloc(i64) allocsize(0)

; We would need context sensitive reasoning about frees (which we don't
; don't currently have) to hoist the load in this example.
define i8 @test_hoist_allocsize() {
; CHECK-LABEL: @test_hoist_allocsize(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[A_RAW:%.*]] = call nonnull ptr @my_alloc(i64 32)
; CHECK-NEXT:    call void @init(ptr [[A_RAW]])
; CHECK-NEXT:    [[ADDR:%.*]] = getelementptr i8, ptr [[A_RAW]], i32 31
; CHECK-NEXT:    br label [[FOR_BODY:%.*]]
; CHECK:       for.body:
; CHECK-NEXT:    [[IV:%.*]] = phi i64 [ [[IV_NEXT:%.*]], [[FOR_BODY]] ], [ 0, [[ENTRY:%.*]] ]
; CHECK-NEXT:    call void @unknown()
; CHECK-NEXT:    [[RES:%.*]] = load i8, ptr [[ADDR]], align 1
; CHECK-NEXT:    call void @use(i8 [[RES]])
; CHECK-NEXT:    [[IV_NEXT]] = add nuw nsw i64 [[IV]], 1
; CHECK-NEXT:    [[EXITCOND:%.*]] = icmp eq i64 [[IV_NEXT]], 200
; CHECK-NEXT:    br i1 [[EXITCOND]], label [[FOR_END:%.*]], label [[FOR_BODY]]
; CHECK:       for.end:
; CHECK-NEXT:    [[RES_LCSSA:%.*]] = phi i8 [ [[RES]], [[FOR_BODY]] ]
; CHECK-NEXT:    call void @free(ptr [[A_RAW]])
; CHECK-NEXT:    ret i8 [[RES_LCSSA]]
;
entry:
  %a.raw = call nonnull ptr @my_alloc(i64 32)
  call void @init(ptr %a.raw)
  br label %for.body

for.body:
  %iv = phi i64 [ %iv.next, %for.body ], [ 0, %entry ]
  call void @unknown() ;; may throw
  %addr = getelementptr i8, ptr %a.raw, i32 31
  %res = load i8, ptr %addr
  call void @use(i8 %res)
  %iv.next = add nuw nsw i64 %iv, 1
  %exitcond = icmp eq i64 %iv.next, 200
  br i1 %exitcond, label %for.end, label %for.body

for.end:
  call void @free(ptr %a.raw)
  ret i8 %res
}

define i8 @test_hoist_allocsize_leak() nofree nosync {
; CHECK-LABEL: @test_hoist_allocsize_leak(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[A_RAW:%.*]] = call nonnull ptr @my_alloc(i64 32)
; CHECK-NEXT:    call void @init(ptr [[A_RAW]])
; CHECK-NEXT:    [[ADDR:%.*]] = getelementptr i8, ptr [[A_RAW]], i32 31
; CHECK-NEXT:    br label [[FOR_BODY:%.*]]
; CHECK:       for.body:
; CHECK-NEXT:    [[IV:%.*]] = phi i64 [ [[IV_NEXT:%.*]], [[FOR_BODY]] ], [ 0, [[ENTRY:%.*]] ]
; CHECK-NEXT:    call void @unknown()
; CHECK-NEXT:    [[RES:%.*]] = load i8, ptr [[ADDR]], align 1
; CHECK-NEXT:    call void @use(i8 [[RES]])
; CHECK-NEXT:    [[IV_NEXT]] = add nuw nsw i64 [[IV]], 1
; CHECK-NEXT:    [[EXITCOND:%.*]] = icmp eq i64 [[IV_NEXT]], 200
; CHECK-NEXT:    br i1 [[EXITCOND]], label [[FOR_END:%.*]], label [[FOR_BODY]]
; CHECK:       for.end:
; CHECK-NEXT:    [[RES_LCSSA:%.*]] = phi i8 [ [[RES]], [[FOR_BODY]] ]
; CHECK-NEXT:    ret i8 [[RES_LCSSA]]
;
entry:
  %a.raw = call nonnull ptr @my_alloc(i64 32)
  call void @init(ptr %a.raw)
  br label %for.body

for.body:
  %iv = phi i64 [ %iv.next, %for.body ], [ 0, %entry ]
  call void @unknown() ;; may throw
  %addr = getelementptr i8, ptr %a.raw, i32 31
  %res = load i8, ptr %addr
  call void @use(i8 %res)
  %iv.next = add nuw nsw i64 %iv, 1
  %exitcond = icmp eq i64 %iv.next, 200
  br i1 %exitcond, label %for.end, label %for.body

for.end:
  ret i8 %res
}
