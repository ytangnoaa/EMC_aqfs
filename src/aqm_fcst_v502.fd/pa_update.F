
!------------------------------------------------------------------------!
!  The Community Multiscale Air Quality (CMAQ) system software is in     !
!  continuous development by various groups and is based on information  !
!  from these groups: Federal Government employees, contractors working  !
!  within a United States Government contract, and non-Federal sources   !
!  including research institutions.  These groups give the Government    !
!  permission to use, prepare derivative works of, and distribute copies !
!  of their work in the CMAQ system to the public and to permit others   !
!  to do so.  The United States Environmental Protection Agency          !
!  therefore grants similar permission to use the CMAQ system software,  !
!  but users are requested to provide copies of derivative works or      !
!  products designed to operate in the CMAQ system to the United States  !
!  Government without restrictions as to use by others.  Software        !
!  that is used with the CMAQ system but distributed under the GNU       !
!  General Public License or the GNU Lesser General Public License is    !
!  subject to their copyright restrictions.                              !
!------------------------------------------------------------------------!


C RCS file, release, date & time of last delta, author, state, [and locker]
C $Header: /project/yoj/arc/CCTM/src/procan/pa/pa_update.F,v 1.10 2011/12/08 16:22:11 sjr Exp $

      SUBROUTINE PA_UPDATE( PRNAME, CGRID, JDATE, JTIME, TSTEP )

C**********************************************************************
C Function: Update the Process Analysis output arrays (for IPR only)
 
C Preconditions: None
 
C Key Subroutines/Functions Called: None
 
C Revision History:
C  Prototype created by Jerry Gipson, July, 1996
C  Modified May, 1997 by Jerry Gipson to be consistent with beta CTM
C  Modified Sept, 1997 by Jerry Gipson to be consistent with targeted CTM
C  Modified March, 1998 by Jerry Gipson to use units of moles/s for all
C                                       emisssions except aerosols
C  Modified Jun, 1998 by Jerry Gipson to add PING process
C  Modified Jun, 1998 by Jerry Gipson to print warning for unexpected
C                                     processes rather than abort
C  Modified 1/19/99 by David Wong at LM:
C                      -- add DATA_COPY function call to redistribute PA grid
C  Modified 2/26/99 by David Wong at LM:
C                      -- replaced DATA_COPY function with dimension specific
C                         DATA_COPY function and modified its argument list
C                      -- used ifdef statement to distinguish parallel
C                         implementation of IRR calculation which does not
C                         start at the origin
C  Modified 4/13/00 by Jerry Gipson to add AE surface area and correct AE
C                                   deposition sign
C  Modified 4/17/00 by David Wong at LM:
C                      -- bug fix: declare TDDEP as a 2D data rather than 3D,
C                         and use 2DE DATA COPY communication routine rather
C                         than 3D DATA COPY routine
C  Modified 5/4/00 by Jerry Gipson to correct DDEP calculations
C  Modified 22 Nov 00 by J.Young: Dave Wong's f90 stenex DATA_COPY -
C                                 must explicitlt dimension CGRID, VEMIS, and DDEP
C  Modified 20 Jun 01 by J.Young: VEMIS, assumed shape
C                                 VEMIS assumed converted to ppm/sec form
C                                 NOTE: the arguments to DATA_COPY must have the layer
C                                 dimension the same as the full domain.
C  Modified 28 aug 01 by J.Young: dyn alloc - Use PAGRD_DEFN,
C                                 which uses HGRD_DEFN; replace INTERP3 with INTERPX
C                                 7 Mar 02 - J.Young: add units string variations
C  Modified  9 Oct 03 by J.Gipson: fixed subscript error for NR EMIS IPRs & re-did
C                                  AE EMIS IPRS for VEMIS in ppm units rather than
C                                  ug/m3 units
C  Modified 5 Nov 03 by J. Gipson to fix DDEP IPRs
C  Modified 25 Nov 03 by J Gipson to use step end time for couple/decouple
C  Modified 31 Jan 05 J.Young: dyn alloc - establish both horizontal & vertical
C                              domain specifications in one module (GRID_CONF)
C   3 Apr 09 J.Young: replace EMISPRM... include files with simpler implementation
C  21 Jun 10 J.Young: convert for Namelist redesign
C  16 Feb 11 S.Roselle: replaced I/O API include files with UTILIO_DEFN
C  11 May 11 D.Wong: incorporated twoway model implementation
C**********************************************************************

      USE GRID_CONF             ! horizontal & vertical domain configuration
      USE CGRID_SPCS            ! CGRID mechanism species
      USE PAGRD_DEFN            ! PA horiz domain specs
      USE AERO_EMIS
      USE UTILIO_DEFN
      USE SUBST_MODULES              ! stenex
!     USE SUBST_DATA_COPY_MODULE     ! stenex

      IMPLICIT NONE 

C Includes:
      INCLUDE SUBST_CONST       ! Constants
      INCLUDE SUBST_FILES_ID    ! file name parameters
      INCLUDE SUBST_PACTL_ID    ! PA control parameters
      INCLUDE SUBST_PACMN_ID    ! PA control parameters
      INCLUDE SUBST_EMISPRM     ! Emissions processing control parameters
      
C Arguments:
      CHARACTER( * ) :: PRNAME   ! Last process called
!     REAL CGRID( NCOLS, NROWS, NLAYS, N_SPCS )  ! Conc array
!     REAL :: CGRID( :,:,:,: )  ! Conc array
      REAL, POINTER :: CGRID( :,:,:,: )  ! Conc array
      INTEGER JDATE    !  current date,    format YYYYDDD
      INTEGER JTIME    !  current time,    format HHMMSS
      INTEGER TSTEP( 3 )   ! time step vector (HHMMSS)
                           ! TSTEP(1) = local output step
                           ! TSTEP(2) = sciproc sync. step (chem)
                           ! TSTEP(3) = twoway model time step w.r.t. wrf time
                           !            step and wrf/cmaq call frequency

C Gas species counts:
      INTEGER, SAVE :: N_SPCS
      REAL :: VEMIS ( :,:,:,: )  ! Emission rates (g/s)
      REAL :: DDEP ( :,:,: )     ! Dry dep (Kg/ha)

C Dimension index assigned for VDIF
      INTEGER, PARAMETER :: IND_VM = 1

C Dimension index assigned for CHEM 
      INTEGER, PARAMETER :: IND_CH = 2

C Dimension index assigned for AERO 
      INTEGER, PARAMETER :: IND_AE = 3

C Maximum allowable number of unexpected processes
      INTEGER, PARAMETER :: MXUNEXP = 50

C 1 hectare = 1.0e4 m**2
      REAL, PARAMETER :: CONVH2M = 1.0E-4

C mass to ppm factor
      REAL, PARAMETER :: CONVMW = 1.0E+06 * MWAIR

C aerosol emission conversion factor terms
      REAL, PARAMETER :: GPKG = 1.0E+03              ! g/kg
      REAL, PARAMETER :: MGPG = 1.0E+06              ! micro-g/g
      REAL, PARAMETER :: REFAC = 1.0E-06 * GPKG * MGPG / MWAIR

C External Functions: 
      INTEGER, EXTERNAL :: FINDEX    ! Finds the index of a number in a list

C Saved Local Variables:
      CHARACTER( 16 ), SAVE :: UNEXPPR( MXUNEXP )

      INTEGER, SAVE :: EMISLYRS
      INTEGER, SAVE :: NUNEXP = 0 ! Number of unexpected processes
      INTEGER, SAVE :: PRINDEM   ! Emissions output index
      INTEGER, SAVE :: PRINDVD   ! Vertical diffusion output index
      INTEGER, SAVE :: PRINDCH   ! Chemistry output index
      INTEGER, SAVE :: PRINDDD   ! Dry deposition output index
      INTEGER, SAVE :: PRINDAE   ! Dry deposition output index

C Indices for emission species in IPR outputs
      INTEGER, SAVE :: IPR_NGR2EM( N_IPR_SPCD, MXCGRIDD, 3 )

      LOGICAL, SAVE :: IPR_AESPEC( N_IPR_SPCD, MXCGRIDD ) ! AE species?

C Indices for dep species in IPR outputs
      INTEGER, SAVE :: IPR_NGR2DD( N_IPR_SPCD, MXCGRIDD )

      LOGICAL, SAVE :: LEMFIRST = .TRUE. ! Flag for 1st call of emis processing
      LOGICAL, SAVE :: LDDFIRST = .TRUE. ! Flag for 1st call of ddep processing

      LOGICAL, SAVE :: EM_AERO = .TRUE.   ! do aero emis processing in vdiff?
!     LOGICAL, SAVE :: EM_AERO = .FALSE.  ! set just for testing former method
      LOGICAL, SAVE :: LAE_EM_IPR = .FALSE.  ! AE EMIS IPR requested?

      REAL, SAVE :: CONVDD( 1 )       ! Conversion factor for dry dep
!     REAL, SAVE :: CONVEM( NLAYS )   ! Conversion factor for emissions

      REAL, ALLOCATABLE, SAVE :: NUMFAC( : )  ! ddep conversion factor (AE only)
C ddep species mass to molar conversion factor
      REAL, ALLOCATABLE, SAVE :: RELWTDD( : )
C emiss species mass to molar conversion factor 
      REAL, ALLOCATABLE, SAVE :: RELWTEM( : )
C ae_conversion factors
      REAL, ALLOCATABLE, SAVE :: AE_EM_CONV( : )

C Reciprocal of map scale factor
      REAL, ALLOCATABLE, SAVE :: RMSFX2( :,: )   
      REAL, ALLOCATABLE, SAVE :: TRMSFX2( :,: )   

C Offset for gases in vdif vs. chem gas-phase emis
      INTEGER, SAVE :: OFFSETG
C Offset for aerosols in vdif vs. chem gas-phase emis
      INTEGER, SAVE :: OFFSETA

C Local Variables:
      CHARACTER( 80 ) :: MSG                  ! Message for output log
      CHARACTER( 16 ) :: PNAME = 'PA_UPDATE'  ! Routine name
      CHARACTER( 16 ) :: UNITS                ! Units of emissions
      CHARACTER( 16 ) :: VNAME                !  input variable name list

      INTEGER ALLOCSTAT ! Allocate status code
      INTEGER C         ! Loop index for columns
      INTEGER ICG       ! Index for species in cgrid array
      INTEGER IDD       ! Index for deposition species
      INTEGER IEM       ! Index for emission species
      INTEGER IND       ! Species index
      INTEGER IPA       ! Index of process monitoring output
      INTEGER IPDD      ! Index of PA deposition output variable
      INTEGER IPEM      ! Index of PA emissions output variable
      INTEGER IPAJ      ! Index of PA vert. diff./chem output variable
      INTEGER ISV       ! Index for saved species conc array 
      INTEGER L         ! Loop index for layers
      INTEGER MDATE     ! Date of mid-point of timestep
      INTEGER MTIME     ! Time of mid-point of timestep
      INTEGER N         ! Loop index for saved species conc array
      INTEGER NGR       ! Loop index for number of cgrid species
      INTEGER NPA       ! No. of process monitoring outputs
!     INTEGER OFFSETG   ! Offset for gases in vdif vs. chem gas-phase emis
!     INTEGER OFFSETA   ! Offset for aerosols in vdif vs. chem gas-phase emis
      INTEGER PC        ! Index for PA output column
      INTEGER PL        ! Index for PA output level
      INTEGER PR        ! Index for PA output row
      INTEGER PRIND     ! Science process index
      INTEGER R         ! Loop index for rows
      INTEGER SP_INDX   ! Index of species in its class
      INTEGER SDATE     ! Date at end of timestep
      INTEGER STIME     ! Time at end of timestep
      INTEGER TOPLEV    ! Highest level for emisssions processing
      INTEGER UNIND     ! Index for unexpected processes

      LOGICAL LAESP     ! Flag for AE species

      REAL    CONVFC    ! Temporary conversion factor
      REAL    DT        ! Timestep in seconds
      REAL    DDX       ! Cell inverse x-dimension
      REAL    DDY       ! Cell inverse y-dimension
      REAL    DX        ! Cell x-dimension
      REAL    DY        ! Cell  y-dimension
      REAL    EM        ! Computed emission rate
      REAL    NETDEP    ! Net dep for hour, converted to  kg/m**3

      REAL :: TCGRID( NCOLS,NROWS,NLAYS )  

      REAL :: DENSA_J ( NCOLS,NROWS,NLAYS )  ! Density times Jacobian
      REAL :: TDENSA_J( NCOLS,NROWS,NLAYS )  

      REAL :: DENS ( NCOLS,NROWS,NLAYS )     ! Density of air
      REAL :: TDENS( NCOLS,NROWS,NLAYS )  

      REAL :: TVEMIS( NCOLS,NROWS,NLAYS )

      REAL :: TDDEP( NCOLS,NROWS )

      REAL :: ZF ( NCOLS,NROWS,NLAYS )       ! Layer heights
      REAL :: TZF( NCOLS,NROWS,NLAYS )

      REAL :: X3FACE( 0:NLAYS )  ! vertical coordinate layer surface
!     REAL :: X3MIDL(   NLAYS )  ! vertical coordinate layer center

      INTEGER      GXOFF, GYOFF             ! global origin offset from file
C for INTERPX
      INTEGER, SAVE :: STRTCOLMC3, ENDCOLMC3, STRTROWMC3, ENDROWMC3
      INTEGER, SAVE :: STRTCOLGC2, ENDCOLGC2, STRTROWGC2, ENDROWGC2
    
      INTERFACE
         SUBROUTINE COUPLE ( CGRID, JDATE, JTIME, TSTEP )
            IMPLICIT NONE
            REAL, POINTER         :: CGRID( :,:,:,: )
            INTEGER, INTENT( IN ) :: JDATE, JTIME
            INTEGER, INTENT( IN ) :: TSTEP( 3 )
         END SUBROUTINE COUPLE
         SUBROUTINE DECOUPLE ( CGRID, JDATE, JTIME, TSTEP )
            IMPLICIT NONE
            REAL, POINTER         :: CGRID( :,:,:,: )
            INTEGER, INTENT( IN ) :: JDATE, JTIME
            INTEGER, INTENT( IN ) :: TSTEP( 3 )
         END SUBROUTINE DECOUPLE
      END INTERFACE

C**********************************************************************

C Get process index and convert units if necessary
      PRIND = INDEX1( PRNAME, NPRCS, PROCNAME )

      IF ( PRIND .EQ. 0 ) THEN
         UNIND = INDEX1( PRNAME, MXUNEXP, UNEXPPR )
         IF ( UNIND .EQ. 0 ) THEN
            MSG = 'Warning: Process Analysis not expecting process ' // PRNAME 
            CALL M3MESG( MSG )
            NUNEXP = NUNEXP + 1
            IF ( NUNEXP .GT. MXUNEXP ) THEN
               MSG = 'Maximum number of unexpected processes for '
     &              // 'Process Analysis exceeded' 
               CALL M3EXIT( PNAME, JDATE, JTIME, MSG, XSTAT1 )
            END IF
            UNEXPPR( NUNEXP ) = PRNAME
         END IF
      END IF
      
      IF ( PRNAME .NE. 'VDIF' .AND. PRNAME .NE. 'CLDS' .AND.
     &     PRNAME .NE. 'CHEM' .AND. PRNAME .NE. 'AERO' ) THEN
         SDATE = JDATE; STIME = JTIME
         CALL NEXTIME( SDATE, STIME, TSTEP( 2 ) )
         CALL DECOUPLE( CGRID, SDATE, STIME, TSTEP )
      END IF

C..Compute delta conc for this process if requested
      IF ( PRIND .GT. 0 .AND. LPROCOUT( PRIND ) ) THEN
         DO NPA = 1, N_IPR_SPC
            IPA = IPROUT( NPA,PRIND )
            IF ( IPA .NE. 0 ) THEN
               DO NGR = 1, NCGRID( NPA )
                  ICG = IPR2GRD( NPA,NGR )
                  ISV = IPR2SAV( NPA,NGR )
#ifdef parallel
                  CALL SUBST_DATA_COPY( CGRID, TCGRID, ICG )
                  DO L = MY_BEGLEV, MY_ENDLEV
                     DO R = MY_BEGROW, MY_ENDROW
                        DO C = MY_BEGCOL, MY_ENDCOL
                           DELC( C,R,L,IPA ) = DELC( C,R,L,IPA )
     &                                       + SPCOEF( NPA,NGR )
     &                                       * ( TCGRID( C,R,L )
     &                                       -   CSAV( C,R,L,ISV ) )
                        END DO
                     END DO
                  END DO
#else
                  DO L = MY_BEGLEV, MY_ENDLEV
                     PL = L - MY_BEGLEV + 1
                     DO R = MY_BEGROW, MY_ENDROW
                        PR = R - MY_BEGROW + 1
                        DO C = MY_BEGCOL, MY_ENDCOL
                           PC = C - MY_BEGCOL + 1
                           DELC( PC,PR,PL,IPA ) = DELC( PC,PR,PL,IPA )
     &                                          + SPCOEF( NPA,NGR )
     &                                          * ( CGRID( C,R,L,ICG )
     &                                          -   CSAV( PC,PR,PL,ISV ) )
                        END DO
                     END DO
                  END DO
#endif
               END DO
            END IF
         END DO 
      END IF

C..Save concentrations for next delta c
      DO N = 1, NCSAVE
         ICG = SV2GRD( N )

#ifdef parallel
         CALL SUBST_DATA_COPY( CGRID, CSAV, ICG, N )
#else
         DO L = MY_BEGLEV, MY_ENDLEV
            PL = L - MY_BEGLEV + 1
            DO R = MY_BEGROW, MY_ENDROW
               PR = R - MY_BEGROW + 1
               DO C = MY_BEGCOL, MY_ENDCOL
                  PC = C - MY_BEGCOL + 1
                  CSAV( PC,PR,PL,N ) = CGRID( C,R,L,ICG ) 
               END DO   
            END DO
         END DO
#endif
      END DO

C..Re-convert units if necessary and return 
      IF ( PRNAME .NE. 'VDIF' .AND. PRNAME .NE. 'CLDS' .AND.
     &     PRNAME .NE. 'CHEM' .AND. PRNAME .NE. 'AERO' ) THEN
         CALL COUPLE( CGRID, SDATE, STIME, TSTEP )
      END IF

      RETURN

ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
C  Emissions processing section
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      ENTRY PA_UPDATE_EMIS( PRNAME, VEMIS, JDATE, JTIME, TSTEP )

C..On first call, set pointers to emission species
      IF ( LEMFIRST ) THEN

#ifdef emis_chem
         EMISVD = .FALSE.
#else
         EMISVD = .TRUE.
#endif

         ALLOCATE ( AE_EM_CONV( N_AE_EMIS ), STAT = ALLOCSTAT )
         IF ( ALLOCSTAT .NE. 0 ) THEN
            MSG = 'Failure allocating AE_EM_CONV'
            CALL M3EXIT( PNAME, JDATE, JTIME, MSG, XSTAT1 )
         END IF

C..Set-up pointers to emis, vdiff, chem, and aero processes         
         PRINDEM = INDEX1( 'EMIS', NPRCS, PROCNAME )
         PRINDVD = INDEX1( 'VDIF', NPRCS, PROCNAME )
         PRINDCH = INDEX1( 'CHEM', NPRCS, PROCNAME )
         PRINDAE = INDEX1( 'AERO', NPRCS, PROCNAME )

C..Set an index offset if reactive gas emissions are done in VDIF
         IF ( EMISVD ) THEN
            OFFSETG = N_GC_EMIS
         ELSE
            OFFSETG = 0
         END IF
C..Set an index offset if aerosol emissions are done in VDIF
         IF ( EM_AERO ) THEN
            OFFSETA = OFFSETG + N_AE_EMIS
         ELSE
            OFFSETA = OFFSETG
         END IF

#ifdef Verbose
         write( *,* ) ' No. of families: ', N_IPR_SPC
#endif

C..Set the pointers to the emission array
         DO NPA = 1, N_IPR_SPC            ! foreach family

#ifdef Verbose
            write( *,* ) ' '
            write( *,* ) ' family index (NPA), NCGRID: ', NPA, NCGRID( NPA )
#endif

            DO NGR = 1, NCGRID( NPA )     ! foreach species in the family

#ifdef Verbose
               write( *,* ) ' CTM species index (NGR), IPR2GRD: ',
     &                        NGR, IPR2GRD( NPA,NGR )
#endif

               ICG = IPR2GRD( NPA,NGR )  ! CTM species index in the family
               IPR_NGR2EM( NPA,NGR,IND_VM ) = 0 
               IPR_NGR2EM( NPA,NGR,IND_CH ) = 0 
               IPR_NGR2EM( NPA,NGR,IND_AE ) = 0
               IPR_AESPEC( NPA,NGR ) = .FALSE.
               IND = 0

C..gas chem species
               IF ( ICG .LE. N_GC_SPC ) THEN

                  SP_INDX = ICG - GC_STRT + 1
                  IND = FINDEX( SP_INDX, N_GC_EMIS, GC_EMIS_MAP )

                  IF ( IND .GT. 0 ) THEN
                     IF ( EMISVD ) THEN
                        IPR_NGR2EM( NPA,NGR,IND_VM ) = IND 
                     ELSE
                        IPR_NGR2EM( NPA,NGR,IND_CH ) = IND 
                        IPR_NGR2EM( NPA,NGR,IND_AE ) = 0
                     END IF
!                    RELWTEM( ICG ) = CONVMW / GC_MOLWT( ICG )
!                    EM_FAC ( ICG ) = GC_EMIS_FAC( IND )
                  END IF   

C..aerosol species
               ELSE IF ( ICG. GE. AE_STRT .AND. ICG .LT. NR_STRT ) THEN

                  SP_INDX = ICG - AE_STRT + 1
                  IND = FINDEX ( SP_INDX, N_AE_EMIS, AE_EMIS_MAP )

                  IF ( IND .GT. 0 ) THEN
                     IF ( EM_AERO ) THEN
                        IPR_NGR2EM( NPA,NGR,IND_VM ) = IND + OFFSETG
                        IPR_AESPEC( NPA,NGR ) = .TRUE.
                        LAE_EM_IPR = .TRUE.
                     ELSE   ! PA in aero process not implemented
                        IPR_NGR2EM( NPA,NGR,IND_AE ) = 0
                     END IF
#ifdef Verbose
                  write( *,* ) ' aero: NPA, NGR, IND_VM, IPR_NGR2EM =',
     &                      NPA, NGR, IND_VM, IPR_NGR2EM( NPA,NGR,IND_VM )
#endif
                  END IF

C..non-reactive species
               ELSE IF ( ICG. GE. NR_STRT .AND. ICG .LT. TR_STRT ) THEN

                  SP_INDX = ICG - NR_STRT + 1  
                  IND = FINDEX ( SP_INDX, N_NR_EMIS, NR_EMIS_MAP )
                  IF ( IND .GT. 0 ) THEN
                     IPR_NGR2EM( NPA,NGR,IND_VM ) = IND + OFFSETA

#ifdef Verbose
                     write( *,* ) ' nonr: NPA, NGR, IND_VM, IPR_NGR2EM =',
     &                         NPA, NGR, IND_VM, IPR_NGR2EM( NPA, NGR, IND_VM )
#endif

!                    RELWTEM( ICG ) = CONVMW / NR_MOLWT( SP_INDX )   
!                    EM_FAC(  ICG ) = NR_EMIS_FAC( IND )
                  END IF   

C..tracer species
               ELSE IF ( ICG. GE. TR_STRT ) THEN

                  SP_INDX = ICG - TR_STRT + 1  
                  IND = FINDEX ( SP_INDX, N_TR_EMIS, TR_EMIS_MAP )

                  IF ( IND .GT. 0 ) THEN
#ifdef Verbose
                     write( *,* ) 'trac ind: ', ind
#endif
                     IPR_NGR2EM( NPA,NGR,IND_VM ) = IND + OFFSETA + N_NR_EMIS
                  END IF

               END IF

#ifdef Verbose
               write( *,* ) ' IPR_NGR2EM( NPA,NGR,IND_VM ): ',
     &                        IPR_NGR2EM( NPA,NGR,IND_VM )
               write( *,* ) ' IPR_NGR2EM( NPA,NGR,IND_CH ): ',
     &                        IPR_NGR2EM( NPA,NGR,IND_CH )
               write( *,* ) ' IPR_NGR2EM( NPA,NGR,IND_AE ): ',
     &                        IPR_NGR2EM( NPA,NGR,IND_AE )
#endif

            END DO      ! end species in the family loop
         END DO         ! end family loop

C..set layer layer thickenesses
!        X3FACE( 0 ) = VGLVS_GD( 1 )
!        DO L = 1, NLAYS
!           X3FACE( L ) = VGLVS_GD( L + 1 )
!           X3MIDL( L ) = 0.5 * ( X3FACE( L ) + X3FACE( L - 1 ) )
!        END DO

C..set cell widths
         IF ( GDTYP_GD .EQ. LATGRD3 ) THEN
            DX = DG2M * XCELL_GD          ! in m.
            DY = DG2M * YCELL_GD *
     &           COS( PI180 * ( YORIG_GD + YCELL_GD * 
     &           FLOAT( NROWS ) ) )       ! in m.
         ELSE
            DX = XCELL_GD                  ! in m
            DY = YCELL_GD                  ! in m
         END IF
         DDX = 1.0 / DX
         DDY = 1.0 / DY

C..check units on emissions file
         IF ( .NOT. DESC3( EMIS_1 ) ) THEN
              MSG = 'Could not get '// EMIS_1 // ' file description'
            CALL M3EXIT( PNAME, JDATE, JTIME, MSG, XSTAT2 )
         END IF

         CALL UPCASE ( UNITS3D( 1 ) )
         IF ( UNITS3D( 1 ) .NE. 'MOLES/S'   .AND.
     &        UNITS3D( 1 ) .NE. 'MOLE/S'    .AND.
     &        UNITS3D( 1 ) .NE. 'MOL/S'     .AND.
     &        UNITS3D( 1 ) .NE. 'MOLES/SEC' .AND.
     &        UNITS3D( 1 ) .NE. 'MOLE/SEC'  .AND.
     &        UNITS3D( 1 ) .NE. 'MOL/SEC' ) THEN
            MSG = 'Units incorrect on ' // EMIS_1
            CALL M3EXIT( PNAME, JDATE, JTIME, MSG, XSTAT1 )
         END IF

C..get number of emission layers
         EMISLYRS = NLAYS3D
         
         LEMFIRST = .FALSE.

         CALL SUBHFILE ( MET_CRO_3D, GXOFF, GYOFF,
     &                   STRTCOLMC3, ENDCOLMC3, STRTROWMC3, ENDROWMC3 )

C..get conversion factors for aero emissions; as of sep 03 release, incoming
C  units are in ppmV/sec for ae species, # aer x 10**6/ # molec air / sec for
C  NUM, and m2/mol sec for SRF.  Conversion factors convert to 
C  ug/m3 sec, #/m3 sec, and m2/m3 sec, respectively.

         IF ( LAE_EM_IPR ) THEN

            DO N = 1, N_AE_EMIS

               IF ( INDEX( AE_EMIS( N ), 'NUM' ) .NE. 0 ) THEN
                  AE_EM_CONV( N ) = REFAC * AVO / MGPG
               ELSE IF ( INDEX( AE_EMIS( N ), 'SRF' ) .NE. 0 ) THEN
                  AE_EM_CONV( N ) = 1.0E+06 * REFAC / MGPG
               ELSE
                  AE_EM_CONV( N ) = REFAC * AE_MOLWT( AE_EMIS_MAP( N ) )
               END IF

            END DO

        END IF

      END IF  ! LEMFIRST

C..get midpoint of time step
      MDATE = JDATE
      MTIME = JTIME
      CALL NEXTIME( MDATE, MTIME, SEC2TIME( TIME2SEC( TSTEP( 2 ) ) / 2 ) ) 

C..Get air density if needed

!     VNAME = 'DENSA_J'
!     IF ( .NOT. INTERPX( MET_CRO_3D, VNAME, 'PA_UPDATE',
!!   &                    1,NCOLS, 1,NROWS, 1,NLAYS,
!    &                    STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3, 1,NLAYS,
!    &                    MDATE, MTIME, DENSA_J ) ) THEN
!           CALL M3EXIT( PNAME, JDATE, JTIME,
!    &                  'Could not interpolate DENSA_J', XSTAT1 )
!     END IF

      IF ( LAE_EM_IPR ) THEN
         VNAME = 'DENS'
         IF ( .NOT. INTERPX( MET_CRO_3D, VNAME, 'PA_UPDATE',
     &                       STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3, 
     &                       1,NLAYS,MDATE, MTIME, DENS ) ) THEN
           CALL M3EXIT( PNAME, JDATE, JTIME,
     &                  'Could not interpolate DENS', XSTAT1 )
         END IF
      END IF


C..Compute delta conc due to emissions and adjust vdiff or chem
C..output if necessary for each output species
      TOPLEV = MIN( MY_ENDLEV, EMISLYRS )
      DT = FLOAT( TIME2SEC( TSTEP( 2 ) ) )

      DO NPA = 1, N_IPR_SPC              ! foreach family
         IPEM = IPROUT( NPA,PRINDEM )    ! emis species index for this process

         IPAJ = 0
         IF ( PRNAME .EQ. 'VDIF' ) THEN
            IPAJ = IPROUT( NPA,PRINDVD )
            IND = IND_VM
         ELSE IF ( PRNAME .EQ. 'CHEM' ) THEN
            IPAJ = IPROUT( NPA,PRINDCH )
            IND = IND_CH
         ELSE IF ( PRNAME .EQ. 'AERO' ) THEN ! PA in aero not implemented!
            IPAJ = IPROUT( NPA,PRINDAE )
            IND = IND_AE
         END IF

         DO NGR = 1, NCGRID( NPA )       ! foreach species in the family
            ICG = IPR2GRD( NPA,NGR )     ! CTM species index in the family
            IEM = IPR_NGR2EM( NPA,NGR,IND )
            LAESP = IPR_AESPEC( NPA,NGR ) ! Flag for aerosol species

            IF ( IEM .NE. 0 .AND. ( IPEM .NE. 0 .OR. IPAJ .NE. 0 ) ) THEN

#ifdef parallel
               CALL SUBST_DATA_COPY ( VEMIS, TVEMIS, IEM )
               IF ( LAESP ) CALL SUBST_DATA_COPY ( DENS, TDENS )
#endif
               DO L = MY_BEGLEV, TOPLEV
                  PL = L - MY_BEGLEV + 1
                  DO R = MY_BEGROW, MY_ENDROW
                     PR = R - MY_BEGROW + 1
                     DO C = MY_BEGCOL, MY_ENDCOL
                        PC = C - MY_BEGCOL + 1

C..compute the emissions

                        IF ( .NOT. LAESP ) THEN
#ifdef parallel
                           EM = TVEMIS( C,R,L ) * DT
                        ELSE
                           EM = TVEMIS( C,R,L ) * DT * TDENS( C,R,L )
     &                        * AE_EM_CONV( IEM - OFFSETG )
#else
                           EM = VEMIS( C,R,L,IEM ) * DT
                        ELSE
                           EM = VEMIS( C,R,L,IEM ) * DT * DENS( C,R,L )
     &                        * AE_EM_CONV( IEM - OFFSETG )
#endif
                        END IF

C..modify both the emiss process and the calling process
                        IF ( IPEM .NE. 0 ) THEN
                           DELC( PC,PR,PL,IPEM ) = DELC( PC,PR,PL,IPEM )
     &                                           + SPCOEF( NPA,NGR ) * EM
                        END IF
                        IF ( IPAJ .NE. 0 ) THEN
                           DELC( PC,PR,PL,IPAJ ) = DELC( PC,PR,PL,IPAJ )
     &                                           - SPCOEF( NPA,NGR ) * EM
                        END IF
                     END DO
                  END DO
               END DO
            END IF
         END DO
      END DO

      RETURN

ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c  Dry Deposition processing section
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      ENTRY PA_UPDATE_DDEP( PRNAME, DDEP, JDATE, JTIME, TSTEP )

C..On first call, set pointers to deposition species 
      IF ( LDDFIRST ) THEN

         N_SPCS = N_GC_SPCD + N_AE_SPC + N_NR_SPC + N_TR_SPC
         ALLOCATE ( NUMFAC( N_SPCS ),
     &              RELWTDD( N_SPCS ), STAT = ALLOCSTAT )
         IF ( ALLOCSTAT .NE. 0 ) THEN
            MSG = 'Failure allocating NUMFAC or RELWTDD'
            CALL M3EXIT( PNAME, JDATE, JTIME, MSG, XSTAT1 )
         END IF

         PRINDDD = INDEX1( 'DDEP', NPRCS, PROCNAME )
         PRINDVD = INDEX1( 'VDIF', NPRCS, PROCNAME )

C..set pointers for the ddep array
         DO NPA = 1, N_IPR_SPC 
            DO NGR = 1, NCGRID( NPA )

               ICG = IPR2GRD( NPA, NGR )
               IPR_NGR2DD( NPA, NGR ) = 0
               IND = 0

               IF ( ICG .LT. AE_STRT ) THEN

                  SP_INDX = ICG - GC_STRT + 1
                  IND = FINDEX ( SP_INDX, N_GC_DEPV, GC_DEPV_MAP )

                  IF ( IND .NE. 0 ) THEN                  
                     IPR_NGR2DD( NPA, NGR ) = IND
                     RELWTDD( ICG ) = CONVMW / GC_MOLWT( ICG )
                  END IF

               ELSE IF ( ICG .GE. AE_STRT .AND. ICG .LT. NR_STRT ) THEN

                  SP_INDX = ICG - AE_STRT + 1
                  IND = FINDEX ( SP_INDX, N_AE_DEPV, AE_DEPV_MAP )

                  IF ( IND .NE. 0 ) THEN                 
                     IPR_NGR2DD( NPA, NGR ) = N_GC_DEPV + IND
                     IF ( AE_SPC( SP_INDX )( 1:3 ) .EQ. 'NUM' ) THEN
                        NUMFAC( ICG ) = 1.0
                     ELSE IF ( AE_SPC( SP_INDX )( 1:3 ) .EQ. 'SRF' ) THEN
                        NUMFAC( ICG ) = 1.0
                     ELSE
                        NUMFAC( ICG ) = 1.0E+09
                     END IF
                  END IF

               ELSE IF ( ICG .GE. NR_STRT .AND. ICG .LT. TR_STRT ) THEN

                  SP_INDX = ICG - NR_STRT + 1
                  IND = FINDEX ( SP_INDX, N_NR_DEPV, NR_DEPV_MAP )

                  IF ( IND .NE. 0 )  THEN
                     IPR_NGR2DD( NPA, NGR ) = N_GC_DEPV + N_AE_DEPV + IND
                     RELWTDD( ICG ) = CONVMW / NR_MOLWT( SP_INDX )
                  END IF

               ELSE IF ( ICG .GE. TR_STRT ) THEN

                  SP_INDX = ICG - TR_STRT + 1
                  IND = FINDEX ( SP_INDX, N_NR_DEPV, NR_DEPV_MAP )

                  IF ( IND .NE. 0 ) THEN
                     IPR_NGR2DD( NPA, NGR ) = N_GC_DEPV + N_AE_DEPV
     &                                      + N_NR_DEPV + IND
                     RELWTDD( ICG ) = CONVMW / TR_MOLWT( SP_INDX )
                  END IF
               END IF
            END DO            
         END DO


C..set layer layer thickenesses
         X3FACE( 0 ) = VGLVS_GD( 1 )
         DO L = 1, NLAYS
            X3FACE( L ) = VGLVS_GD( L + 1 )
         END DO

         L = 1
         CONVDD( L ) = 1.0 / ABS ( X3FACE( L ) - X3FACE( L - 1 ) ) 

c..get recipricol of msfx2
         CALL SUBHFILE( GRID_CRO_2D, GXOFF, GYOFF,
     &                  STRTCOLGC2, ENDCOLGC2, STRTROWGC2, ENDROWGC2 )

         ALLOCATE ( RMSFX2( NCOLS,NROWS ), STAT = ALLOCSTAT )
         IF ( ALLOCSTAT .NE. 0 ) THEN
            MSG = 'Failure allocating RMSFX4'
            CALL M3EXIT( PNAME, JDATE, JTIME, MSG, XSTAT1 )
         END IF

         VNAME = 'MSFX2'
         IF ( .NOT. INTERPX( GRID_CRO_2D, VNAME, PNAME,
     &                       STRTCOLGC2,ENDCOLGC2, STRTROWGC2,ENDROWGC2, 1,1,
     &                       JDATE, JTIME, RMSFX2 ) ) THEN
            MSG = ' Error interpolating variable ' // TRIM( VNAME )
     &          // ' from ' // GRID_CRO_2D
            CALL M3EXIT( PNAME, JDATE, JTIME, MSG, XSTAT1 )
         END IF

         RMSFX2 = 1.0 /  RMSFX2        ! Array calculation

#ifdef parallel
         ALLOCATE ( TRMSFX2( NCOLS,NROWS ), STAT = ALLOCSTAT )
         IF ( ALLOCSTAT .NE. 0 ) THEN
            MSG = 'Failure allocating RMSFX4'
            CALL M3EXIT( PNAME, JDATE, JTIME, MSG, XSTAT1 )
         END IF

         CALL SUBST_DATA_COPY( RMSFX2, TRMSFX2 )
#endif
         
         CALL SUBHFILE ( MET_CRO_3D, GXOFF, GYOFF,
     &                   STRTCOLMC3, ENDCOLMC3, STRTROWMC3, ENDROWMC3 )

         LDDFIRST = .FALSE.           

      END IF

      IF ( MY_BEGLEV .GT. 1 ) RETURN

C..get midpoint of time step
      MDATE = JDATE
      MTIME = JTIME
      CALL NEXTIME( MDATE, MTIME, SEC2TIME( TIME2SEC( TSTEP( 2 ) ) / 2 ) )

C..get density x jacobian and layer heights

      VNAME = 'DENSA_J'
      IF ( .NOT. INTERPX( MET_CRO_3D, VNAME, 'PA_UPDATE',
     &                    STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3, 1,NLAYS,
     &                    MDATE, MTIME, DENSA_J ) ) THEN
            CALL M3EXIT( PNAME, JDATE, JTIME,
     &                   'Could not interpolate DENSA_J', XSTAT1 )
      END IF

      IF ( N_AE_SPC .GT. 0 ) THEN

         VNAME = 'ZF'
         IF ( .NOT. INTERPX( MET_CRO_3D, VNAME, 'PA_UPDATE',
     &                       STRTCOLMC3,ENDCOLMC3, STRTROWMC3,ENDROWMC3,1,NLAYS,
     &                       MDATE, MTIME, ZF ) ) THEN
               CALL M3EXIT( PNAME, JDATE, JTIME,
     &                      'Could not interpolate ZF', XSTAT1 )
         END IF
      END IF

#ifdef parallel
      CALL SUBST_DATA_COPY( DENSA_J, TDENSA_J )

      IF ( N_AE_SPC .GT. 0 ) THEN
         CALL SUBST_DATA_COPY ( ZF, TZF )
         END IF
#endif

C..Compute delta conc due to ddep and adjust vdiff output if necessary
      DO NPA = 1, N_IPR_SPC
         IPDD = IPROUT( NPA,PRINDDD )
         IPAJ = IPROUT( NPA,PRINDVD ) 

         DO NGR = 1, NCGRID( NPA )                       
            ICG = IPR2GRD( NPA,NGR )
            IDD = IPR_NGR2DD( NPA,NGR )

            IF ( IDD .NE. 0 .AND. ( IPDD .NE. 0 .OR. IPAJ .NE. 0 ) ) THEN

#ifdef parallel
               CALL SUBST_DATA_COPY( DDEP, TDDEP, IDD )
#endif

               DO R = MY_BEGROW, MY_ENDROW
                  PR = R - MY_BEGROW + 1
                  DO C = MY_BEGCOL, MY_ENDCOL
                     PC = C - MY_BEGCOL + 1

C..compute the dep in ppm

                     IF ( ICG .GE. AE_STRT. AND. ICG .LT. NR_STRT ) THEN
#ifdef parallel
                        NETDEP = TDDEP( C,R ) * CONVH2M
     &                         * NUMFAC( ICG ) / TZF( C,R,1 )
                     ELSE
                        NETDEP = TDDEP( C,R ) * CONVH2M
     &                         * RELWTDD( ICG ) * CONVDD( 1 )
     &                         * TRMSFX2( C,R ) / TDENSA_J( C,R,1 ) 

#else
                        NETDEP = DDEP( C,R,IDD ) * CONVH2M
     &                         * NUMFAC( ICG ) / ZF( C,R,1 )
                     ELSE
                        NETDEP = DDEP( C,R,IDD ) * CONVH2M
     &                         * RELWTDD( ICG ) * CONVDD( 1 )
     &                         * RMSFX2( C,R ) / DENSA_J( C,R,1 ) 
#endif
                     END IF

C..adjust the process analysis output arrays

                     IF ( IPDD .NE .0 ) THEN
                        DELC( PC,PR,1,IPDD ) = DELC( PC,PR,1,IPDD )
     &                                       - SPCOEF( NPA,NGR ) * NETDEP
                     END IF

                     IF ( IPAJ .NE. 0 ) THEN
                        DELC( PC,PR,1,IPAJ ) = DELC( PC,PR,1,IPAJ )  
     &                                       + SPCOEF( NPA,NGR ) * NETDEP
                     END IF
                  END DO   ! C
               END DO   ! R

            END IF
         END DO   ! NGR
      END DO   ! NPA

      RETURN
      END           
