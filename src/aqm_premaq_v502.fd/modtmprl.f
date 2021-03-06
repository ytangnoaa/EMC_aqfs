
        MODULE MODTMPRL

!***********************************************************************
!  Module body starts at line
!
!  DESCRIPTION:
!     This module contains temporal allocation information. 
!
!  PRECONDITIONS REQUIRED:
!
!  SUBROUTINES AND FUNCTIONS CALLED:
!
!  REVISION HISTORY:
!     Created 1/99 by M. Houyoux for temporal profiles only
!     Changed 10/2000 by MRH to include additional temporal info.
!
!***************************************************************************
!
! Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
!                System
! File: @(#)$Id: modtmprl.f,v 1.9 2004/06/27 01:58:22 cseppan Exp $
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
! Pathname: $Source: /afs/isis/depts/cep/emc/apps/archive/smoke/smoke/src/emmod/modtmprl.f,v $
! Last updated: $Date: 2004/06/27 01:58:22 $ 
!
!****************************************************************************

        IMPLICIT NONE

        INCLUDE 'EMPRVT3.EXT'

!.........  Hourly-emissions file information
        INTEGER, PUBLIC :: NTPDAT   ! No. data values in hourly emissions file
        CHARACTER(IOVLEN3), ALLOCATABLE, PUBLIC :: TPNAME( : )  ! data names
        CHARACTER(IOULEN3), ALLOCATABLE, PUBLIC :: TPUNIT( : )  ! data units
        CHARACTER(IODLEN3), ALLOCATABLE, PUBLIC :: TPDESC( : )  ! data descs

!.........  Holiday dates arrays
        INTEGER, PUBLIC :: NHOLIDAY  ! number of holidays

        INTEGER, ALLOCATABLE, PUBLIC :: HOLREGN ( : ) ! Region code of holiday
        INTEGER, ALLOCATABLE, PUBLIC :: HOLJDATE( : ) ! Julian date of holidays
        INTEGER, ALLOCATABLE, PUBLIC :: HOLALTDY( : ) ! alternative day of week

!.........  Sorted temporal profiles
        INTEGER, PUBLIC :: NMON   ! number of monthly profiles
        INTEGER, PUBLIC :: NWEK   ! number of weekly profiles
        INTEGER, PUBLIC :: NHRL   ! number of diurnal profiles 

        INTEGER, ALLOCATABLE, PUBLIC :: MONREF( : )   ! Monthly codes
        INTEGER, ALLOCATABLE, PUBLIC :: WEKREF( : )   ! Weekly codes 
        INTEGER, ALLOCATABLE, PUBLIC :: HRLREF( : )   ! Diurnal codes

        REAL   , ALLOCATABLE, PUBLIC :: MONFAC( :,: ) ! Monthly factors
        REAL   , ALLOCATABLE, PUBLIC :: WEKFAC( :,: ) ! Weekly facs (week-norm)
        REAL   , ALLOCATABLE, PUBLIC :: XWKFAC( :,: ) ! Weekly facs (wkday-norm)
        REAL   , ALLOCATABLE, PUBLIC :: HRLFAC( :,:,: ) ! Hourly factors

        END MODULE MODTMPRL
