
        SUBROUTINE SETDAYLT

C***********************************************************************
C  subroutine body starts at line
C
C  DESCRIPTION:
C      This subroutine allocates and populates the by-source array that
C      indicates which sources get daylight time and which do not.
C 
C  PRECONDITIONS REQUIRED:
C      Number of sources set
C      Region codes read from inventory file.
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C
C  REVISION  HISTORY:
C      Created 10/2000 by M. Houyoux
C
C************************************************************************
C
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id: setdaylt.f,v 1.5 2004/06/21 17:30:55 cseppan Exp $
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
C Pathname: $Source: /afs/isis/depts/cep/emc/apps/archive/smoke/smoke/src/temporal/setdaylt.f,v $
C Last updated: $Date: 2004/06/21 17:30:55 $ 
C
C***************************************************************************

C...........   MODULES for public variables
C.........  This module contains the inventory arrays
        USE MODSOURC, ONLY: FLTRDAYL, IFIP

C.........  This module contains the arrays for state and county summaries
        USE MODSTCY, ONLY: NCOUNTY, CNTYCOD, USEDAYLT

C.........  This module contains the information about the source category
        USE MODINFO, ONLY: NSRC

        IMPLICIT NONE

C...........   INCLUDES

        INCLUDE 'EMCNST3.EXT'   !  emissions constat parameters

C...........   EXTERNAL FUNCTIONS and their descriptions:
        INTEGER         FIND1

        EXTERNAL        FIND1

C...........   Other local variables

        INTEGER         J, S        ! counters and indices

        INTEGER         FIP         ! tmp region code
        INTEGER         FLTR        ! tmp filter value
        INTEGER         IOS         ! i/o status
        INTEGER         PFIP        ! region code from previous iteration

        CHARACTER(300)  MESG        ! message buffer 

        CHARACTER(16) :: PROGNAME = 'SETDAYLT' ! program name

C***********************************************************************
C   begin body of subroutine SETDAYLT

C.........  Allocate memory for daylight time filter
        ALLOCATE( FLTRDAYL( NSRC ), STAT=IOS )
        CALL CHECKMEM( IOS, 'FLTRDAYL', PROGNAME )

C.........  Initialize all sources as using daylight time
        FLTRDAYL = 1    ! array

C.........  Use region codes daylight time assignment information (from MODSTCY)
C           to set sources that do not use daylight time
C.........  No error if region code is not found in list, because if it is
C           not in the list, then the daylight status can remain in use
        PFIP = 0
        DO S = 1, NSRC

            FIP = IFIP( S )
            
            IF( FIP .NE. PFIP ) THEN

                J = FIND1( FIP, NCOUNTY, CNTYCOD )

                FLTR = 1
                IF( J .GT. 0 ) THEN

                    IF( .NOT. USEDAYLT( J ) ) FLTR = 0

                END IF

                PFIP = FIP

            END IF

            FLTRDAYL( S ) = FLTR

        END DO 

        RETURN

C******************  FORMAT  STATEMENTS   ******************************

C...........   Internal buffering formats............ 94xxx

94000   FORMAT( I2.2 )
 
94010   FORMAT( 10( A, :, I8, :, 1X ) )

        END SUBROUTINE SETDAYLT

