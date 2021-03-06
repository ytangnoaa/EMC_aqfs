
        MODULE MODMBSET

!***********************************************************************
!  Module body starts at line 42
!
!  DESCRIPTION:
!     This module contains the public allocatable arrays used when
!     setting up MOBILE6 information.
!
!  PRECONDITIONS REQUIRED:
!
!  SUBROUTINES AND FUNCTIONS CALLED:
!
!  REVISION HISTORY:
!     Created 10/01 by C. Seppanen
!
!***************************************************************************
!
! Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
!                System
! File: @(#)$Id: modmbset.f,v 1.4 2004/06/03 14:19:06 cseppan Exp $
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
! Pathname: $Source: /afs/isis/depts/cep/emc/apps/archive/smoke/smoke/src/emmod/modmbset.f,v $
! Last updated: $Date: 2004/06/03 14:19:06 $ 
!
!****************************************************************************

        IMPLICIT NONE

!.........  Arrays for storing file information
        INTEGER, ALLOCATABLE, PUBLIC :: MCREFSORT ( :,: ) ! sorted MCREF data  
        INTEGER, ALLOCATABLE, PUBLIC :: MCREFIDX ( :,: )  ! index into MCREF by ref. county
        
        INTEGER, ALLOCATABLE, PUBLIC :: MVREFSORT ( :,: ) ! sorted MVREF data
        
        INTEGER, PUBLIC :: NREFC           ! no. of reference counties
        INTEGER, PUBLIC :: NINVC           ! no. of unique counties in inventory
        
        INTEGER, PUBLIC :: NREFFLAGS = 3   ! no. of settings flags in MVREF file
        
!.........  Time period constants
        INTEGER, PARAMETER :: DAILY    = 1    ! daily temperature profiles
        INTEGER, PARAMETER :: WEEKLY   = 2    ! weekly temperature averaging
        INTEGER, PARAMETER :: MONTHLY  = 3    ! monthly temperature averaging
        INTEGER, PARAMETER :: EPISLEN  = 4    ! episode length temp. averaging
        
        END MODULE MODMBSET
        
