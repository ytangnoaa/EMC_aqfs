
C.........................................................................
C Version "@(#)$Header$"
C EDSS/Models-3 I/O API.
C Copyright (C) 1992-2002 MCNC and Carlie J. Coats, Jr., and
C (C) 2003 Baron Advanced Meteorological Systems
C Distributed under the GNU LESSER GENERAL PUBLIC LICENSE version 2.1
C See file "LGPL.txt" for conditions of use.
C.........................................................................

        LOGICAL FUNCTION RDGRDDED( FID, VID, LAYER, STEP, BUFFER )

C***********************************************************************
C  function body starts at line  77
C
C  FUNCTION:  reads data from Models-3 GRDDED data file with state-variable
C             index FID, for variable with name VID and layer LAYER, for the
C             time step record STEP.
C             If VID is -1 reads all variables; if LAYER is -1,
C             reads all layers.
C
C  RETURN VALUE:  TRUE iff the operation succeeds (and the data is available)
C
C  PRECONDITIONS REQUIRED:  Should only be called by READ3(), after it
C             has checked for file and time step availability, and that
C             file type is GRDDED3.
C
C  SUBROUTINES AND FUNCTIONS CALLED:  RDVARS
C
C  REVISION  HISTORY:  
C	prototype 3/1992 by CJC
C
C	Modified  9/1994 by CJC:  argument VID not VNAME 
C
C       Modified 10/2003 by CJC for I/O API version 3:  support for
C       native-binary BINFIL3 file type; uses INTEGER NAME2FID
C***********************************************************************

      IMPLICIT NONE

C...........   INCLUDES:

        INCLUDE 'PARMS3.EXT'
        INCLUDE 'STATE3.EXT'
        INCLUDE 'NETCDF.EXT'


C...........   ARGUMENTS and their descriptions:

        INTEGER         FID             !  file index within the STATE3 commons
        INTEGER         VID             !  variable index  or ALLAYS3
        INTEGER         LAYER           !  layer number, or -1 = ALLAYS3
        INTEGER         STEP            !  time step record number
        REAL            BUFFER(*)       !  buffer array for input


C...........   EXTERNAL FUNCTIONS and their descriptions:

        LOGICAL         RDVARS     !  read "variables" part of timestep records
        EXTERNAL        RDVARS
        EXTERNAL        INITBLK3   !  block data: initialize I/O state


C...........   SCRATCH LOCAL VARIABLES and their descriptions:

        INTEGER         DELTA           !  d(INDX) / d(NCVGTcall)
        INTEGER         DIMS ( 5 )      !  corner arg array for NCVGT()
        INTEGER         DELTS( 5 )      !  corner arg array for NCVGT()


C***********************************************************************
C   begin body of function  RDGRDDED

C.......   Set up DIMS and DELTS arguments for NCVGT() according to
C.......   whether request is for all layers:

        DIMS ( 1 ) = 1
        DELTS( 1 ) = NCOLS3( FID )

        DIMS ( 2 ) = 1
        DELTS( 2 ) = NROWS3( FID )

        DIMS ( 4 ) = STEP
        DELTS( 4 ) = 1

        DIMS ( 5 ) = 0
        DELTS( 5 ) = 0

        IF ( LAYER .EQ. ALLAYS3 ) THEN

            DIMS ( 3 ) = 1
            DELTS( 3 ) = NLAYS3( FID )

            DELTA = NCOLS3( FID ) * NROWS3( FID ) * NLAYS3( FID )

        ELSE    !  read a specific layer:

            DIMS ( 3 ) = LAYER
            DELTS( 3 ) = 1

            DELTA = NCOLS3( FID ) * NROWS3( FID )

        END IF          !  if layer == alllays or not


C...........   Perform the reads, according to VID

        RDGRDDED = RDVARS( FID, VID, DIMS, DELTS, DELTA, BUFFER )

        RETURN


        END

