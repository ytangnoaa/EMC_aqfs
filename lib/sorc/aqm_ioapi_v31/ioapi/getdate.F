
        INTEGER FUNCTION GETDATE ( DEFAULT , PROMPT )

C********************************************************************
C Version "$Id: getdate.F 45 2014-09-12 20:05:29Z coats $"
C EDSS/Models-3 I/O API.
C Copyright (C) 1992-2002 MCNC and Carlie J. Coats, Jr.,
C (C) 2003-2010 by Baron Advanced Meteorological Systems.
C Distributed under the GNU LESSER GENERAL PUBLIC LICENSE version 2.1
C See file "LGPL.txt" for conditions of use.
C.........................................................................
C       function body starts at line  58
C
C  FUNCTION:
C
C       Display the  PROMPT  for a date in either of two formats:
C       YYYYDDD or YYYYMMDD
C       For non-IO_360, attempts to detect both Gregorian YYYYMMDD and
C       Julian YYYYDDD representations and return the correct Julian in
C       both cases.
C
C  CALLS:
C       GETNUM. JULIAN
C
C  RETURNS:
C       user response after checking its range; or default.
C
C  REVISION HISTORY:
C
C       Created 1/1997 by M Houyoux, MCNC Environmental Programs
C
C       2/2002 Unification by Carlie J. Coats, Jr., MCNC Environmental
C       Programs with global-climate GETDATE, which uses a 360-day "year".
C
C       Modified 03/20010 by CJC: F9x changes for I/O API v3.1
C****************************************************************************

        IMPLICIT NONE

C.......   ARGUMENTS:

        INTEGER      , INTENT(IN   ) :: DEFAULT         !  Default return date, YYYYDDD
        CHARACTER*(*), INTENT(IN   ) :: PROMPT          !  Prompt for user

C.......   EXTERNAL FUNCTIONS:

        INTEGER, EXTERNAL :: GETNUM, JULIAN


C.......   LOCAL VARIABLES:

        INTEGER         JDATE, YEAR, MONTH, DAY
        CHARACTER*256   MESG

C......................................................................
C       begin GETDATE

11      CONTINUE

        JDATE = GETNUM( 0, 999999999, DEFAULT, PROMPT )

#ifndef IO_360

C.........  For Gregorian input date - convert to Julian

        IF( JDATE .GT. 9999999 ) THEN

            YEAR = JDATE/10000
            MONTH = ( JDATE-YEAR*10000 ) / 100
            DAY   = MOD( JDATE-YEAR*10000, 100 )
            JDATE = YEAR*1000 + JULIAN( YEAR, MONTH, DAY )

        ENDIF

C.........  Check range

        IF( JDATE .LT. 1970001 .OR. JDATE .GT. 2100365 ) THEN

            MESG = 'Date is out of acceptable modeling range'
            CALL M3WARN( 'GETDATE', 0, 0, MESG )

            GO TO 11   ! Read in date again.

        ENDIF
#endif

        WRITE( MESG, '( A, I9.7 )' ) 'Using date', JDATE
        CALL M3MSG2( MESG )
        GETDATE = JDATE

        RETURN

        END FUNCTION GETDATE

