
        REAL FUNCTION STR2REAL( STRING )

C***********************************************************************
C Version "$Id: str2real.f 45 2014-09-12 20:05:29Z coats $"
C EDSS/Models-3 I/O API.
C Copyright (C) 1992-2002 MCNC and Carlie J. Coats, Jr.,
C (C) 2003-2010 by Baron Advanced Meteorological Systems.
C Distributed under the GNU LESSER GENERAL PUBLIC LICENSE version 2.1
C See file "LGPL.txt" for conditions of use.
C.........................................................................
C  function body starts at line  57
C
C  RETURNS:
C       REAL value decoded from STRING, or BADVAL3 for "missing",
C       after skipping leading blanks.
C
C  PRECONDITIONS REQUIRED:
C       Properly formatted REAL in STRING
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C       M3ERR()
C
C  REVISION  HISTORY:
C       Prototype 6/95 by CJC for point source prototype
C
C       Modified 03/20010 by CJC: F90 changes for I/O API v3.1
C***********************************************************************

      IMPLICIT NONE

C...........   INCLUDES:

        INCLUDE 'PARMS3.EXT'


C...........   ARGUMENTS and their descriptions:

        CHARACTER*(*), INTENT(IN   ) :: STRING


C...........   PARAMETERS
            
        CHARACTER*1, PARAMETER :: BLANK = ' '
        
C...........   SCRATCH LOCAL VARIABLES and their descriptions:

        REAL		VAL
        INTEGER         I, L, N, P, IOS
        CHARACTER*8     FMT
        CHARACTER*80    MSG


C***********************************************************************
C   begin body of function  STR2REAL

        L = LEN_TRIM( STRING )
            
        DO  11  I = 1, L        !  skip leading whitespace
            IF ( STRING( I:I ) .GT. BLANK ) GO TO 12
11      CONTINUE

C.......   If you get to here:  no number there

        STR2REAL = BADVAL3
        RETURN

12      CONTINUE                 
        N = L - I + 1
        P = INDEX( STRING( I:L ), '.' )
        IF ( P .GT. 0 ) THEN
            WRITE( FMT, 94010 ) N, N - P
        ELSE
            WRITE( FMT, 94010 ) N, 0
        END IF

        READ( STRING( I:L ), FMT, IOSTAT = IOS ) VAL

        IF( IOS .NE. 0 ) THEN
            WRITE( MSG,94020 ) 
     &          'Error reading REAL from "', STRING( I:L ), 
     &          '"; IOSTAT=', IOS
            CALL M3WARN( 'STR2REAL', 0, 0, MSG )
            STR2REAL = BADVAL3
        ELSE
            STR2REAL = VAL
        END IF
        
        RETURN

94010   FORMAT( '(G', I2.2, '.', I2.2, ')' )

94020   FORMAT( 3A, I7 )

        END FUNCTION STR2REAL

