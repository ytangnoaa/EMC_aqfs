
       SUBROUTINE PLSPRD( DTHDZ, ZF, KZ, CEFSTK, HTMIX,
     &                    PLTOP, PLBOT )
     
C***********************************************************************
C  subroutine body starts at line 70
C
C  DESCRIPTION:  
C       Calculates the initial vertical spread of a plume; modified
C       from Gillani's model.
C
C  PRECONDITIONS REQUIRED:
C
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C
C
C  REVISION  HISTORY:
C       Created from code by Jim Godowitch at EPA, 9/03
C
C***********************************************************************
C  
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id: plsprd.f,v 1.3 2004/06/03 14:45:09 cseppan Exp $
C  
C COPYRIGHT (C) 2004, Environmental Modeling for Policy Development
C All Rights Reserved
C 
C Carolina Environmental Program
C University of North Carolina at Chapel Hill
C 137 E. Franklin St., CB# 6116
C Chapel Hill, NC 27599-6116
C 
C smoke@unc.edu
C  
C Pathname: $Source: /afs/isis/depts/cep/emc/apps/archive/smoke/smoke/src/point/plsprd.f,v $
C Last updated: $Date: 2004/06/03 14:45:09 $ 
C  
C***********************************************************************

       IMPLICIT NONE
       
C...........   ARGUMENTS and their descriptions:

       REAL,    INTENT  (IN) :: DTHDZ( KZ )    ! potential temperature lapsed rate
       REAL,    INTENT  (IN) :: ZF( 0:KZ )     ! elevation by layer
       INTEGER, INTENT  (IN) :: KZ             ! number of emissions layers
       REAL,    INTENT  (IN) :: CEFSTK         ! effective stack height
       REAL,    INTENT  (IN) :: HTMIX          ! mixing height
       REAL,    INTENT (OUT) :: PLTOP          ! plume top
       REAL,    INTENT (OUT) :: PLBOT          ! plume bottom
       
C...........   PARAMETERS and their descriptions:
       REAL, PARAMETER :: SZ0FAC = 3.545    ! factor used to derive plume depth
       REAL, PARAMETER :: SPRFAC = 15.      ! empirical coefficient for vertical spread
       REAL, PARAMETER :: GAMA   = -0.0098
       
C...........   Local variables
       INTEGER    K
       
       REAL       SIGZ0
       REAL       DTDZ
       REAL       DPTH
       
C***********************************************************************
C   begin body of subroutine  PLSPRD

C........  Get ambient temperature above plume rise height (effective stack height)
       K = 0
       DO 
           K = K + 1
           IF( K == KZ .OR. CEFSTK <= ZF( K ) ) EXIT
       END DO
       DTDZ  = DTHDZ( K ) + GAMA
       
C........  Compute initial vertical spread
       SIGZ0 = MAX( 10.0, SPRFAC * EXP( -117. * DTDZ ) )
       DPTH  = SZ0FAC * SIGZ0
       
C........  Compute plume top and bottom heights; plume is either completely
C          within or outside mixing layer
       PLTOP = CEFSTK + DPTH/2.
       PLBOT = CEFSTK - DPTH/2.
       
C........  Make sure plume bottom is at least zero
       PLBOT = MAX( 0.0, PLBOT )
       
       PLTOP = MIN( ZF( KZ ), PLTOP )
       
       RETURN
       
       END SUBROUTINE PLSPRD
       
