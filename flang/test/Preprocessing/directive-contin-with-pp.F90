! RUN: %flang_fc1 -fdebug-unparse -fopenmp %s 2>&1 | FileCheck %s

#define DIR_START !dir$
#define DIR_CONT !dir$&
#define FIRST(x) DIR_START x
#define NEXT(x) DIR_CONT x
#define AMPER &
#define COMMENT !
#define OMP_START !$omp
#define OMP_CONT !$omp&
#define EMPTY

module m
 contains
  subroutine s1(x1, x2, x3, x4, x5, x6, x7)

!dir$ ignore_tkr x1

!dir$ ignore_tkr &
!dir$& x2

DIR_START ignore_tkr x3

!dir$ ignore_tkr AMPER
DIR_CONT x4

FIRST(ignore_tkr &)
!dir$& x5

FIRST(ignore_tkr &)
NEXT(x6)

COMMENT blah &
COMMENT & more
    stop 1

OMP_START parallel &
OMP_START do &
OMP_START reduction(+:x)
    do j1 = 1, n
    end do

OMP_START parallel &
OMP_START & do &
OMP_START & reduction(+:x)
    do j2 = 1, n
    end do

OMP_START parallel &
OMP_CONT do &
OMP_CONT reduction(+:x)
    do j3 = 1, n
    end do

EMPTY !$omp parallel &
EMPTY !$omp do
    do j4 = 1, n
    end do
  end

COMMENT &
  subroutine s2
  end subroutine
COMMENT&
  subroutine s3
  end subroutine
end module

!CHECK: MODULE m
!CHECK: CONTAINS
!CHECK:  SUBROUTINE s1 (x1, x2, x3, x4, x5, x6, x7)
!CHECK:   !DIR$ IGNORE_TKR x1
!CHECK:   !DIR$ IGNORE_TKR x2
!CHECK:   !DIR$ IGNORE_TKR x3
!CHECK:   !DIR$ IGNORE_TKR x4
!CHECK:   !DIR$ IGNORE_TKR x5
!CHECK:   !DIR$ IGNORE_TKR x6
!CHECK:   STOP 1_4
!CHECK: !$OMP PARALLEL DO  REDUCTION(+: x)
!CHECK:   DO j1=1_4,n
!CHECK:   END DO
!CHECK: !$OMP PARALLEL DO  REDUCTION(+: x)
!CHECK:   DO j2=1_4,n
!CHECK:   END DO
!CHECK: !$OMP PARALLEL DO  REDUCTION(+: x)
!CHECK:   DO j3=1_4,n
!CHECK:   END DO
!CHECK: !$OMP PARALLEL DO
!CHECK:   DO j4=1_4,n
!CHECK:   END DO
!CHECK:  END SUBROUTINE
!CHECK:  SUBROUTINE s2
!CHECK:  END SUBROUTINE
!CHECK:  SUBROUTINE s3
!CHECK:  END SUBROUTINE
!CHECK: END MODULE
