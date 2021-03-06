
        MODULE MODSOURC

!***********************************************************************
!  Module body starts at line 41
!
!  DESCRIPTION:
!     This module contains the public allocatable arrays for the source
!     characteristics (both sorted and unsorted)
!
!  PRECONDITIONS REQUIRED:
!
!  SUBROUTINES AND FUNCTIONS CALLED:
!
!  REVISION HISTORY:
!     Created 1/99 by M. Houyoux
!
!***************************************************************************
!
! Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
!                System
! File: @(#)$Id: modsourc.f,v 1.14 2004/06/21 17:23:03 cseppan Exp $
!
! COPYRIGHT (C) 2004, Environmental Modeling for Policy Development
! All Rights Reserved
! 
! Carolina Environmental Program
! University of North Carolina at Chapel Hill
! 137 E. Franklin St., CB# 6116
! Chapel Hill, NC 27599-6116
! 
! smoke@unc.edu
!
! Pathname: $Source: /afs/isis/depts/cep/emc/apps/archive/smoke/smoke/src/emmod/modsourc.f,v $
! Last updated: $Date: 2004/06/21 17:23:03 $ 
!
!****************************************************************************

        IMPLICIT NONE

        INCLUDE 'EMPRVT3.EXT'   !  emissions private parameters

!.........  Sorted list of point sources for SMOKE inventory file
        INTEGER, POINTER,     PUBLIC:: IFIP  ( : )  !  source FIPS (county) ID
        INTEGER, POINTER,     PUBLIC:: ISIC  ( : )  !  source SIC
        INTEGER, ALLOCATABLE, PUBLIC:: IRCLAS( : )  !  road class number
        INTEGER, ALLOCATABLE, PUBLIC:: IVTYPE( : )  !  vehicle type code
        INTEGER, ALLOCATABLE, PUBLIC:: CELLID( : )  !  Cell ID
        INTEGER, POINTER,     PUBLIC:: IPOSCOD( : ) !  positn of pol in INVPCOD
        INTEGER, ALLOCATABLE, PUBLIC:: TZONES( : )  !  time zones
        INTEGER, POINTER,     PUBLIC:: TPFLAG( : )  !  temporal profile types
        INTEGER, POINTER,     PUBLIC:: INVYR ( : )  !  inv year for this record
        INTEGER, ALLOCATABLE, PUBLIC:: IDIU  ( : )  !  Hr prof code per source
        INTEGER, ALLOCATABLE, PUBLIC:: IWEK  ( : )  !  Wk prof code per source
        INTEGER, ALLOCATABLE, PUBLIC:: IMON  ( : )  !  Mn prof code per source
        INTEGER, POINTER,     PUBLIC:: NPCNT ( : )  !  No. of pols per raw rec
        INTEGER, ALLOCATABLE, PUBLIC:: FLTRDAYL( : )!  daylight time filter
        INTEGER, ALLOCATABLE, PUBLIC:: SRGID ( :,: )!  primary & fallbk surg ID

        REAL   , ALLOCATABLE, PUBLIC:: XLOCA ( : )  !  lon X-location 
        REAL   , ALLOCATABLE, PUBLIC:: YLOCA ( : )  !  lat Y-location 
        REAL   , ALLOCATABLE, PUBLIC:: XLOC1 ( : )  !  lon X-location link start 
        REAL   , ALLOCATABLE, PUBLIC:: YLOC1 ( : )  !  lat Y-location link start
        REAL   , ALLOCATABLE, PUBLIC:: XLOC2 ( : )  !  lon X-location link end 
        REAL   , ALLOCATABLE, PUBLIC:: YLOC2 ( : )  !  lat Y-location link end
        REAL   , ALLOCATABLE, PUBLIC:: SPEED ( : )  !  speed
        REAL   , ALLOCATABLE, PUBLIC:: STKHT ( : )  !  stack height   (m)
        REAL   , ALLOCATABLE, PUBLIC:: STKDM ( : )  !  stack diameter (m)
        REAL   , ALLOCATABLE, PUBLIC:: STKTK ( : )  !  exhaust temp   (deg K)
        REAL   , ALLOCATABLE, PUBLIC:: STKVE ( : )  !  exhaust veloc  (m/s)
        REAL   , ALLOCATABLE, PUBLIC:: VMT   ( : )  !  vehicle miles traveled (miles/day)

        REAL   , POINTER,     PUBLIC:: POLVAL( :,: )!  pol-spec values by pol

        CHARACTER(SCCLEN3), POINTER,     PUBLIC:: CSCC   ( : ) ! SCC
        CHARACTER(ORSLEN3), ALLOCATABLE, PUBLIC:: CORIS  ( : ) ! DOE plant ID
        CHARACTER(BLRLEN3), ALLOCATABLE, PUBLIC:: CBLRID ( : ) ! boiler ID
        CHARACTER(LNKLEN3), ALLOCATABLE, PUBLIC:: CLINK  ( : ) ! link
        CHARACTER(DSCLEN3), ALLOCATABLE, PUBLIC:: CPDESC ( : ) ! plant desc
        CHARACTER(ALLLEN3), POINTER,     PUBLIC:: CSOURC ( : ) ! concat src
        CHARACTER(VTPLEN3), ALLOCATABLE, PUBLIC:: CVTYPE ( : ) ! vehicle type
        CHARACTER(ERPLEN3), ALLOCATABLE, PUBLIC:: CERPTYP( : ) ! emission release point type
        CHARACTER(MACLEN3), POINTER,     PUBLIC:: CMACT  ( : ) ! MACT code
        CHARACTER(NAILEN3), POINTER,     PUBLIC:: CNAICS ( : ) ! NAICS code
        CHARACTER(STPLEN3), POINTER,     PUBLIC:: CSRCTYP( : ) ! source type code
        
        CHARACTER(SPNLEN3), ALLOCATABLE, PUBLIC:: SPPROF( :,: ) ! spec prof

!.........  Unsorted list of point sources for SMOKE inventory file
        INTEGER, POINTER,     PUBLIC:: INDEXA( : ) !  subscript table for SORTIC
        INTEGER, POINTER,     PUBLIC:: IFIPA ( : ) !  raw state/county FIPS code
        INTEGER, ALLOCATABLE, PUBLIC:: ISICA ( : ) !  raw SIC
        INTEGER, ALLOCATABLE, PUBLIC:: IRCLASA( : )!  road class number
        INTEGER, ALLOCATABLE, PUBLIC:: IVTYPEA( : )!  vehicle type code
        INTEGER, POINTER,     PUBLIC:: IPOSCODA(:) !  positn of pol in INVPCOD
        INTEGER, POINTER,     PUBLIC:: ICASCODA(:) !  positn of CAS num. in UNIQCAS
        INTEGER, POINTER,     PUBLIC:: TPFLGA( : ) !  temporal resolution code
        INTEGER, POINTER,     PUBLIC:: INVYRA( : ) !  inventory year
        INTEGER, ALLOCATABLE, PUBLIC:: IDIUA ( : ) !  Hrly prof code per source
        INTEGER, ALLOCATABLE, PUBLIC:: IWEKA ( : ) !  Wkly prof code per source
        INTEGER, POINTER,     PUBLIC:: INRECA( : ) !  Input record per src x pol
        INTEGER, POINTER,     PUBLIC:: SRCIDA( : ) !  Source ID

        REAL   , POINTER,     PUBLIC:: XLOCAA( : ) !  UTM X-location (m)
        REAL   , POINTER,     PUBLIC:: YLOCAA( : ) !  UTM Y-location (m)
        REAL   , ALLOCATABLE, PUBLIC:: XLOC1A( : ) !  lon X-location link start 
        REAL   , ALLOCATABLE, PUBLIC:: YLOC1A( : ) !  lat Y-location link start
        REAL   , ALLOCATABLE, PUBLIC:: XLOC2A( : ) !  lon X-location link end 
        REAL   , ALLOCATABLE, PUBLIC:: YLOC2A( : ) !  lat Y-location link end
        REAL   , ALLOCATABLE, PUBLIC:: SPEEDA( : ) !  speed
        REAL   , ALLOCATABLE, PUBLIC:: STKHTA( : ) !  stack height   (m)
        REAL   , ALLOCATABLE, PUBLIC:: STKDMA( : ) !  stack diameter (m)
        REAL   , ALLOCATABLE, PUBLIC:: STKTKA( : ) !  exhaust temperature (deg K)
        REAL   , ALLOCATABLE, PUBLIC:: STKVEA( : ) !  exhaust velocity    (m/s)
        REAL   , POINTER,     PUBLIC:: POLVLA( :,: )! emis-spec values. See BLDENAMS.
        REAL   , ALLOCATABLE, PUBLIC:: VMTA  ( : ) !  vehicle miles traveled

        CHARACTER(SCCLEN3), POINTER,     PUBLIC:: CSCCA  ( : ) ! SCC
        CHARACTER(ORSLEN3), ALLOCATABLE, PUBLIC:: CORISA ( : ) ! DOE plant ID
        CHARACTER(BLRLEN3), ALLOCATABLE, PUBLIC:: CBLRIDA( : ) ! boiler ID
        CHARACTER(LNKLEN3), ALLOCATABLE, PUBLIC:: CLINKA ( : ) ! link
        CHARACTER(DSCLEN3), ALLOCATABLE, PUBLIC:: CPDESCA( : ) ! plant desc
        CHARACTER(ALLCAS3), POINTER,     PUBLIC:: CSOURCA( : ) ! concat src
        CHARACTER(VTPLEN3), ALLOCATABLE, PUBLIC:: CVTYPEA( : ) ! vehicle type

!.........  Unsorted list of file numbers and records by source
        INTEGER, PUBLIC :: NSTRECS                      ! size of SRCSBYREC
        INTEGER, ALLOCATABLE, PUBLIC:: SRCSBYREC( :,: ) ! file number, record number, and
                                                        ! src number for each inventory record
        INTEGER, ALLOCATABLE, PUBLIC:: RECIDX( : )      ! index for SRCSBYREC

        END MODULE MODSOURC
