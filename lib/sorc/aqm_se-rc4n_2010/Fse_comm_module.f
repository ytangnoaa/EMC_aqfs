C RCS file, release, date & time of last delta, author, state, [and locker]
C $Header: /project/work/rep/STENEX/src/se_f90/se_comm_module.f,v 1.3 2001/01/24 13:14:30 yoj Exp $

C what(1) key, module and SID; SCCS file; date and time of last delta:
C %W% %P% %G% %U%

C --------------------------------------------------------------------------
C Purpose:
C
C   use F90 interface feature to achieve "faked" polymorphism for pe 
C communication routine and use F90 module feature to modulize pe communication
C functionality of the stencil exchange library
C
C Revision history:
C
C   Orginal version: 11/05/99 by David Wong
C --------------------------------------------------------------------------

	module se_comm_module

        implicit none

        interface se_comm
          module procedure se_pe_comm1, 
     &                     se_pe_comm2, se_pe_comm2e, 
     &                     se_pe_comm3, se_pe_comm3e, 
     &                     se_pe_comm4
        end interface

        contains

C -----------------------------------------------------------------------------
C Purpose:
C
C   determine the set of neighbouring processor(s) that my own processor needs 
C   to communicate with, base upon the input data dependency.
C
C Revision history:
C
C   Orginal version: 7/29/98 by David Wong 
C
C                    11/05/99 by David Wong
C                      -- recode the code using F90 syntax
C                    02/06/02 by David Wong
C                      -- adjust the communication direction if it is NE, SE,
C                         SW, or NW
C
C Subroutine parameter description:
C
C   In: dirstr    -- indicator of communication direction associated with
C                    the data dependency: 0 (without communication), 
C                                         1 (with communication)
C       send_to   -- processor number which data needs to be sent to
C       recv_from -- processor number which data is received from
C
C Local variable description:
C
C   rdirection -- input communication direction for receiveing
C   sdirection -- communication direction for sending
C   i, j, k    -- loop indexes
C
C Include file:
C
C   se_comm_info_ext
C
C     se_ngb_pe -- an array to indicate a communication with a certain 
C                  processor is required base upon near-neighbour communication 
C                  pattern: -1 denotes no communication is needed, and a non 
C                  -1 number denotes processor number with which communication 
C                  is formed
C
C   se_ori_ext
C   se_internal_util_module
C -----------------------------------------------------------------------------

	subroutine se_comm_pat (dirstr, send_to, recv_from)

        use se_comm_info_ext
        use se_ori_ext
        use se_internal_util_module

	implicit none

        character (len = 16), intent(in) :: dirstr
	integer, intent(out) :: send_to (8), recv_from (8)

        integer :: i, j, k
        integer :: rdirection (8), sdirection(8)
	
C -- extract inform from input strings

        read (dirstr, 10) (rdirection(i), i=1, 8)
 10     format (8i2)

C -- make adjustment if communication direction is: NE, SE, SW, or NW

        do i = 2, 8, 2
           if (rdirection(i) .eq. 1) then
              rdirection(mod(i-1,8)) = 1
              rdirection(mod(i+1,8)) = 1
           end if
        end do

        if (se_geo_ori .eq. 0) then
           call swap (rdirection(1), rdirection(5))
           call swap (rdirection(2), rdirection(4))
           call swap (rdirection(8), rdirection(6))
        end if

C -- figuring out send direction pattern
	do i = 1, 8
           sdirection(i) = rdirection(mod(i+3,8)+1)
	end do

C -- determine where data is receiving from
C -- first: N, E, S, and W
        do i = 1, 7, 2
           if ((rdirection (i) .gt. 0) .and.
     &         (se_ngb_pe(i) .ge. 0)) then
              recv_from(i) = se_ngb_pe(i)
           else
              recv_from(i) = -1
           end if
        end do

C -- second: NE, SE, SW, NW, and their immediate neighbours
C --         for instance, NE's immediate neighbours are N, and E
        do i = 2, 8, 2
           if (rdirection(i) .gt. 0) then
              do j = i-1, i+1
                 k = j
                 if (k .eq. 9) then
                    k = 1
                  end if 
                  if (se_ngb_pe(k) .ge. 0) then
                     recv_from(k) = se_ngb_pe(k)
                  else
                     recv_from(k) = -1
                  end if
              end do
           else
              recv_from(i) = -1
           end if
        end do

C -- determine where data is sending to
C -- first: N, E, S, and W
        do i = 1, 7, 2
           if ((sdirection (i) .gt. 0) .and.
     &         (se_ngb_pe(i) .ge. 0)) then
              send_to(i) = se_ngb_pe(i)
           else
              send_to(i) = -1
           end if
        end do

C -- second: NE, SE, SW, NW, and their immediate neighbours
C --         for instance, NE's immediate neighbours are N, and E
        do i = 2, 8, 2
           if (sdirection(i) .gt. 0) then
              do j = i-1, i+1
                 k = j
                 if (k .eq. 9) then
                    k = 1
                  end if 
                  if (se_ngb_pe(k) .ge. 0) then
                     send_to(k) = se_ngb_pe(k)
                  else
                     send_to(k) = -1
                  end if
              end do
           else
              send_to(i) = -1
           end if
        end do

        return
        end subroutine se_comm_pat

C --------------------------------------------------------------------------
C Purpose:
C
C   program se_pe_comm[n][e] performs near-neighbour communication for a 
C n-dimensional data structure
C
C Revision history:
C
C   Orginal version: 9/15/98 by David Wong
C                    11/05/99 by David Wong
C                      -- recode the code using F90 syntax
C                    07/23/01 by David Wong
C                      -- redesign the message sending and receiving algorithm
C                    03/06/02 David Wong
C                      -- use blocking communication scheme
C                      -- use array copy mechanism when communicates to itself
C                    12/04/02 by David Wong
C                      -- modified the routine to accommodate: 1. the
C                         worker and I/O processors partition scheme and 2.
C                         data structure reordering
C                    01/02/03 David Wong
C                      -- modify the code to handle dot file while using dynamic
C                         data allocation
C
C Subroutine parameter description:
C
C   In:  data    -- original data
C        dispstr -- displacement string
C        dirstr  -- indicator of communication direction
C                   0 (without communication), 1 (with communication)
C        str     -- an optional argument to indicate the starting index of 
C                   certain dimension
C        flag    -- to indicate se_pe_comm[n]e is used
C
C   Out: data    -- original data after communication
C
C Local variable description:
C
C    send_to       -- processor number which data needs to be sent to
C    send_to_ptr   -- a F90 pointer (alias) of send_to
C    recv_from     -- processor number which data is recvd from
C    recv_from_ptr -- a F90 pointer (alias) of recv_from
C    sdir, rdir    -- loop indexes which indicate send to or recvd from
C    sind          -- store low and high index of each dimension for sending
C                     process
C    sind_ptr      -- a F90 pointer (alias) of sind
C    rind          -- store low and high index of each dimension for receiving
C                     process
C    rind_ptr      -- a F90 pointer (alias) of rind
C    shift         -- an array to hold the amount of index shifting due to
C                     starting index is 1 in a subroutine
C    num_shift     -- number of shifting
C    loc_str       -- a local copy of str
C
C Include file:
C
C   se_data_send_module
C   se_data_recv_module
C   se_internal_util_module
C
C Subroutine/Function call:
C
C   se_comm_pat
C   se_up_low[1]
C
C --------------------------------------------------------------------------

	subroutine se_pe_comm1 (data, dispstr, dirstr, str)

        use se_data_send_module
        use se_data_recv_module
        use se_internal_util_module
        use se_pe_info_ext

	implicit none

        include "mpif.h"

	real, intent(inout) :: data(:)
        character (len = 16), intent(in) :: dirstr
        character (len = 12), intent(in) :: dispstr
        character (len = *), optional, intent(in) :: str

        integer, target :: sind(2,8), rind(2,8)
        integer, pointer :: sind_ptr(:,:), rind_ptr(:,:)
        integer, target :: send_to(8), recv_from(8)
        integer, pointer :: send_to_ptr(:), recv_from_ptr(:)
        integer :: sdir, rdir
        integer :: shift(2), num_shift
        character (len = 80) :: loc_str
        integer :: request, status(MPI_STATUS_SIZE), error

	if (present(str)) then
           loc_str = str
           call se_string_to_integer (loc_str, shift, num_shift)
        else
           num_shift = 0
        end if

	call se_comm_pat (dirstr, send_to, recv_from)

        call se_up_low1 (dispstr, sind, rind, shift, num_shift, size(data))

        send_to_ptr => send_to
        recv_from_ptr => recv_from
        sind_ptr => sind
        rind_ptr => rind

        do sdir = 1, 8, 2

           rdir = mod((sdir + 3), 8) + 1

           if (send_to(sdir) .eq. se_myworker_pe) then

              data(rind(1,rdir):rind(2,rdir)) = data(sind(1,sdir):sind(2,sdir))

           else 

              if (send_to(sdir) .ge. 0) then
                 call se_data_send (data, sind_ptr, send_to_ptr, sdir, sdir, 
     $                              request)
              end if

              if ((recv_from(rdir) .ge. 0) .and. 
     $            (recv_from(rdir) .ne. se_myworker_pe)) then
                 call se_data_recv (data, rind_ptr, recv_from_ptr, rdir, sdir)
              end if

c             if (send_to(sdir) .ge. 0) then
c                call mpi_wait (request, status, error)
c             end if

           end if
        end do

        return
        end subroutine se_pe_comm1

C --------------------------------------------------------------------------
C Purpose:
C
C   perform near-neighbour communication for a 2-D data structure with 2-D
C decomposition (se_pe_comm2) or 1-D decomposition (se_pe_comm2e)
C
C Revision history:
C
C   Orginal version: 8/3/98 by David Wong
C                    11/05/99 by David Wong
C                      -- recode the code using F90 syntax
C                    07/23/01 by David Wong
C                      -- redesign the message sending and receiving algorithm
C                    03/06/02 David Wong
C                      -- use blocking communication scheme
C                      -- use array copy mechanism when communicates to itself
C                    12/04/02 by David Wong
C                      -- modified the routine to accommodate: 1. the
C                         worker and I/O processors partition scheme and 2.
C                         data structure reordering
C                    01/02/03 David Wong
C                      -- modify the code to handle dot file while using dynamic
C                         data allocation
C
C Subroutine parameter description:
C
C   In:  data    -- original data
C        dispstr -- displacement string
C        dirstr  -- indicator of communication direction
C                   0 (without communication), 1 (with communication)
C        flag    -- to indicate se_pe_comm2e is used
C        str     -- an optional argument to indicate the starting index of
C                   certain dimension
C
C   Out: data    -- original data after communication
C
C Local variable description:
C
C    send_to       -- processor number which data needs to be sent to
C    send_to_ptr   -- a F90 pointer (alias) of send_to
C    recv_from     -- processor number which data is recvd from
C    recv_from_ptr -- a F90 pointer (alias) of recv_from
C    sdir, rdir    -- loop indexes which indicate send to or recvd from
C    sind          -- store low and high index of each dimension for sending
C                     process
C    sind_ptr      -- a F90 pointer (alias) of sind
C    rind          -- store low and high index of each dimension for receiving
C                     process
C    rind_ptr      -- a F90 pointer (alias) of rind
C    shift         -- an array to hold the amount of index shifting due to
C                     starting index is 1 in a subroutine
C    num_shift     -- number of shifting
C    loc_str       -- a local copy of str
C
C Include file:
C
C    se_data_send_module
C    se_data_recv_module
C
C Subroutine/Function call:
C
C   se_comm_pat 
C   se_up_low2 
C
C --------------------------------------------------------------------------

	subroutine se_pe_comm2 (data, dispstr, dirstr, str)

        use se_data_send_module
        use se_data_recv_module
        use se_internal_util_module
        use se_pe_info_ext

	implicit none

        include "mpif.h"

	real, intent(inout) :: data(:,:)
        character (len = 16), intent(in) :: dirstr
        character (len = 12), intent(in) :: dispstr
        character (len = *), optional, intent(in) :: str

        integer, target :: send_to(8), recv_from(8)
        integer, pointer :: send_to_ptr(:), recv_from_ptr(:)
        integer, target :: sind(2,2,8), rind(2,2,8)
        integer, pointer :: sind_ptr(:,:,:), rind_ptr(:,:,:)
        integer :: sdir, rdir
        integer :: shift(4), num_shift
        character (len = 80) :: loc_str
        integer :: request, status(MPI_STATUS_SIZE), error

        if (present(str)) then
           loc_str = str
	   shift(2:4:2) = 1
           call se_string_to_integer (loc_str, shift, num_shift)
        else
           num_shift = 0
        end if

	call se_comm_pat (dirstr, send_to, recv_from)

        send_to_ptr => send_to
        recv_from_ptr => recv_from

        call se_up_low2 (dispstr, sind, rind, shift, num_shift,
     $                   size(data,1), size(data,2))

        sind_ptr => sind
        rind_ptr => rind

        do sdir = 1, 8

           rdir = mod((sdir + 3), 8) + 1

           if (send_to(sdir) .eq. se_myworker_pe) then

              data(rind(1,1,rdir):rind(2,1,rdir),rind(1,2,rdir):rind(2,2,rdir))
     $        =
     $        data(sind(1,1,sdir):sind(2,1,sdir),sind(1,2,sdir):sind(2,2,sdir))

           else

              if (send_to(sdir) .ge. 0) then
                 call se_data_send (data, sind_ptr, send_to_ptr, sdir, sdir, 
     $                              request)
              end if

              if ((recv_from(rdir) .ge. 0) .and.
     $            (recv_from(rdir) .ne. se_myworker_pe)) then
                 call se_data_recv (data, rind_ptr, recv_from_ptr, rdir, sdir)
              end if

c             if (send_to(sdir) .ge. 0) then
c                call mpi_wait (request, status, error)
c             end if

           end if

        end do

	return
        end subroutine se_pe_comm2

C -----------------------------------------------------------------------------
	subroutine se_pe_comm2e (data, dispstr, dirstr, flag, str)

        use se_data_send_module
        use se_data_recv_module
        use se_internal_util_module
        use se_pe_info_ext

	implicit none

        include "mpif.h"

	real, intent(inout) :: data(:,:)
        character (len = 16), intent(in) :: dirstr
        character (len = 12), intent(in) :: dispstr
        integer, intent(in) :: flag
        character (len = *), optional, intent(in) :: str

        integer, target :: send_to(8), recv_from(8)
        integer, pointer :: send_to_ptr(:), recv_from_ptr(:)
        integer, target :: sind(2,8), rind(2,8)
        integer, pointer :: sind_ptr(:,:), rind_ptr(:,:)
        integer :: sdir, rdir
        integer :: shift(4), num_shift
        character (len = 80) :: loc_str
        integer :: request, status(MPI_STATUS_SIZE), error

        if (present(str)) then
           loc_str = str
	   shift(2:4:2) = 1
           call se_string_to_integer (loc_str, shift, num_shift)
        else
           num_shift = 0
        end if

	call se_comm_pat (dirstr, send_to, recv_from)

        send_to_ptr => send_to
        recv_from_ptr => recv_from

        call se_up_low1 (dispstr, sind, rind, shift, num_shift, size(data,1))

        sind_ptr => sind
        rind_ptr => rind

        do sdir = 1, 8, 2

           rdir = mod((sdir + 3), 8) + 1

           if (send_to(sdir) .eq. se_myworker_pe) then

                data(rind(1,rdir):rind(2,rdir),:) 
     $        = data(sind(1,sdir):sind(2,sdir),:)

           else

              if (send_to(sdir) .ge. 0) then
                 call se_data_send (data, sind_ptr, send_to_ptr, sdir, sdir,
     $                              request)
              end if

              if ((recv_from(rdir) .ge. 0) .and.
     $            (recv_from(rdir) .ne. se_myworker_pe)) then
                 call se_data_recv (data, rind_ptr, recv_from_ptr, rdir, sdir)
              end if

c             if (send_to(sdir) .ge. 0) then
c                call mpi_wait (request, status, error)
c             end if

           end if
        end do

	return
        end subroutine se_pe_comm2e

C --------------------------------------------------------------------------
C Purpose:
C
C   perform near-neighbour communication for a 3-D data structure with 2-D
C decomposition (se_pe_comm3) or 1-D decomposition (se_pe_comm3e)
C
C Revision history:
C
C   Orginal version: 7/29/98 by David Wong 
C                    11/05/99 by David Wong
C                      -- recode the code using F90 syntax
C                    07/23/01 by David Wong
C                      -- redesign the message sending and receiving algorithm
C                    03/06/02 David Wong
C                      -- use blocking communication scheme
C                      -- use array copy mechanism when communicates to itself
C                    12/04/02 by David Wong
C                      -- modified the routine to accommodate: 1. the
C                         worker and I/O processors partition scheme and 2.
C                         data structure reordering
C                    01/02/03 David Wong
C                      -- modify the code to handle dot file while using dynamic
C                         data allocation
C                    09/13/04 David Wong
C                      -- used F90 function SIZE to determine the size of the 
C                         third and fourth dimension rather than strictly to
C                         NLVLS and NSPCS, to setup transfer indices, rind and
C                         sind
C
C Subroutine parameter description:
C
C   In:  data    -- original data
C        dispstr -- displacement string
C        dirstr  -- indicator of communication direction
C                   0 (without communication), 1 (with communication)
C        flag    -- to indicate se_pe_comm2e is used
C        str     -- an optional argument to indicate the starting index of
C                   certain dimension
C
C   Out: data     -- original data after communication
C
C Local variable description:
C
C    send_to       -- processor number which data needs to be sent to
C    send_to_ptr   -- a F90 pointer (alias) of send_to
C    recv_from     -- processor number which data is recvd from
C    recv_from_ptr -- a F90 pointer (alias) of recv_from
C    sdir, rdir    -- loop indexes which indicate send to or recvd from
C    rdirection    -- input communication direction for receiveing
C    sdirection    -- communication direction for sending
C    sind          -- store low and high index of each dimension for sending
C                     process
C    sind_ptr      -- a F90 pointer (alias) of sind
C    rind          -- store low and high index of each dimension for receiving
C                     process
C    rind_ptr      -- a F90 pointer (alias) of rind
C    shift         -- an array to hold the amount of index shifting due to
C                     starting index is 1 in a subroutine
C    num_shift     -- number of shifting
C    loc_str       -- a local copy of str
C
C Include file:
C
C    se_data_send_module
C    se_data_recv_module
C
C Subroutine/Function call:
C
C   se_comm_pat
C   se_up_low3
C
C --------------------------------------------------------------------------

	subroutine se_pe_comm3 (data, dispstr, dirstr, str)

        use se_data_send_module
        use se_data_recv_module
        use se_internal_util_module
        use se_pe_info_ext

	implicit none

        include "mpif.h"

	real, intent(inout) ::  data(:,:,:)
        character (len = 16), intent(in) :: dirstr
        character (len = 12), intent(in) :: dispstr
        character (len = *), optional, intent(in) :: str

        integer, target :: send_to(8), recv_from(8)
        integer, pointer :: send_to_ptr(:), recv_from_ptr(:)
        integer, target :: sind(2,3,8), rind(2,3,8)
        integer, pointer :: sind_ptr(:,:,:), rind_ptr(:,:,:)
        integer :: sdir, rdir
        integer :: shift(6), num_shift
        character (len = 80) :: loc_str
        integer :: request, status(MPI_STATUS_SIZE), error

        if (present(str)) then
           loc_str = str
           shift(2:6:2) = 1
           call se_string_to_integer (loc_str, shift, num_shift)
        else
           num_shift = 0
        end if

        call se_comm_pat (dirstr, send_to, recv_from)

        send_to_ptr => send_to
        recv_from_ptr => recv_from

        call se_up_low3 (dispstr, sind, rind, shift, num_shift,
     $                   size(data,1), size(data,2), size(data,3))

        sind_ptr => sind
        rind_ptr => rind

        do sdir = 1, 8

           rdir = mod((sdir + 3), 8) + 1

           if (send_to(sdir) .eq. se_myworker_pe) then

                data(rind(1,1,rdir):rind(2,1,rdir),
     $               rind(1,2,rdir):rind(2,2,rdir),
     $               rind(1,3,rdir):rind(2,3,rdir))
     $        = data(sind(1,1,sdir):sind(2,1,sdir),
     $               sind(1,2,sdir):sind(2,2,sdir),
     $               sind(1,3,sdir):sind(2,3,sdir))

           else

              if (send_to(sdir) .ge. 0) then
                 call se_data_send (data, sind_ptr, send_to_ptr, sdir, sdir,
     $                              request)
              end if

              if ((recv_from(rdir) .ge. 0) .and.
     $            (recv_from(rdir) .ne. se_myworker_pe)) then
                 call se_data_recv (data, rind_ptr, recv_from_ptr, rdir, sdir)
              end if

c             if (send_to(sdir) .ge. 0) then
c                call mpi_wait (request, status, error)
c             end if

           end if
        end do
 
	return
        end subroutine se_pe_comm3

C --------------------------------------------------------------------------
	subroutine se_pe_comm3e (data, dispstr, dirstr, flag, str)

        use se_data_send_module
        use se_data_recv_module
        use se_internal_util_module
        use se_pe_info_ext

	implicit none

        include "mpif.h"

	real, intent(inout) ::  data(:,:,:)
        character (len = 16), intent(in) :: dirstr
        character (len = 12), intent(in) :: dispstr
        integer, intent(in) :: flag
        character (len = *), optional, intent(in) :: str

        integer, target :: send_to(8), recv_from(8)
        integer, pointer :: send_to_ptr(:), recv_from_ptr(:)
        integer, target :: sind(2,8), rind(2,8)
        integer, pointer :: sind_ptr(:,:), rind_ptr(:,:)
        integer :: sdir, rdir
        integer :: shift(6), num_shift
        character (len = 80) :: loc_str
        integer :: request, status(MPI_STATUS_SIZE), error

        if (present(str)) then
           loc_str = str
           shift(2:6:2) = 1
           call se_string_to_integer (loc_str, shift, num_shift)
        else
           num_shift = 0
        end if

        call se_comm_pat (dirstr, send_to, recv_from)

        send_to_ptr => send_to
        recv_from_ptr => recv_from

        call se_up_low1 (dispstr, sind, rind, shift, num_shift, size(data,1))

        sind_ptr => sind
        rind_ptr => rind

        do sdir = 1, 8, 2

           rdir = mod((sdir + 3), 8) + 1

           if (send_to(sdir) .eq. se_myworker_pe) then

                data(rind(1,rdir):rind(2,rdir),:,:)
     $        = data(sind(1,sdir):sind(2,sdir),:,:)

           else
              if (send_to(sdir) .ge. 0) then
                 call se_data_send (data, sind_ptr, send_to_ptr, sdir, sdir,
     $                              request)
              end if

              if ((recv_from(rdir) .ge. 0) .and.
     $            (recv_from(rdir) .ne. se_myworker_pe)) then
                 call se_data_recv (data, rind_ptr, recv_from_ptr, rdir, sdir)
              end if

c             if (send_to(sdir) .ge. 0) then
c                call mpi_wait (request, status, error)
c             end if

           end if
        end do
 
	return
        end subroutine se_pe_comm3e

C --------------------------------------------------------------------------
C Purpose:
C
C   perform near-neighbour communication for a 4-D data structure with 2-D
C decomposition 
C
C Revision history:
C
C   Orginal version: 7/31/98 by David Wong
C                    11/05/99 by David Wong
C                      -- recode the code using F90 syntax
C                    07/23/01 by David Wong
C                      -- redesign the message sending and receiving algorithm
C                    03/06/02 David Wong
C                      -- use blocking communication scheme
C                      -- use array copy mechanism when communicates to itself
C                    12/04/02 by David Wong
C                      -- modified the routine to accommodate: 1. the
C                         worker and I/O processors partition scheme and 2.
C                         data structure reordering
C                    01/02/03 David Wong
C                      -- modify the code to handle dot file while using dynamic
C                         data allocation
C                    09/13/04 David Wong
C                      -- used F90 function SIZE to determine the size of the 
C                         third and fourth dimension rather than strictly to
C                         NLVLS and NSPCS, to setup transfer indices, rind and
C                         sind
C
C Subroutine parameter description:
C
C   In:  data    -- original data
C        dispstr -- displacement string
C        dirstr  -- indicator of communication direction
C                   0 (without communication), 1 (with communication)
C        str     -- an optional argument to indicate the starting index of
C                   certain dimension
C
C   Out: data    -- original data after communication
C
C Local variable description:
C
C    send_to       -- processor number which data needs to be sent to
C    send_to_ptr   -- a F90 pointer (alias) of send_to
C    recv_from     -- processor number which data is recvd from
C    recv_from_ptr -- a F90 pointer (alias) of recv_from
C    sdir, rdir    -- loop indexes which indicate send to or recvd from
C    sind          -- store low and high index of each dimension for sending
C                     process
C    sind_ptr      -- a F90 pointer (alias) of sind
C    rind          -- store low and high index of each dimension for receiving
C                     process
C    rind_ptr      -- a F90 pointer (alias) of rind
C    shift         -- an array to hold the amount of index shifting due to
C                     starting index is 1 in a subroutine
C    num_shift     -- number of shifting
C    loc_str       -- a local copy of str
C
C Include file:
C
C    se_data_send_module
C    se_data_recv_module
C
C Subroutine/Function call:
C
C   se_comm_pat
C   se_up_low4
C
C --------------------------------------------------------------------------

	subroutine se_pe_comm4 (data, dispstr, dirstr, str)

        use se_data_send_module
        use se_data_recv_module
        use se_internal_util_module
        use se_pe_info_ext

	implicit none

        include "mpif.h"

        real, intent(inout) :: data(:,:,:,:)
        character (len = 16), intent(in) :: dirstr
        character (len = 12), intent(in) :: dispstr
        character (len = *), optional, intent(in) :: str

        integer, target :: send_to(8), recv_from(8)
        integer, pointer :: send_to_ptr(:), recv_from_ptr(:)
        integer, target :: sind(2,4,8), rind(2,4,8)
        integer, pointer :: sind_ptr(:,:,:), rind_ptr(:,:,:)
        integer :: sdir, rdir
        integer :: shift(8), num_shift
        character (len = 80) :: loc_str
        integer :: request, status(MPI_STATUS_SIZE), error

        if (present(str)) then
           loc_str = str
           shift(2:8:2) = 1
           call se_string_to_integer (loc_str, shift, num_shift)
        else
           num_shift = 0
        end if

        call se_comm_pat (dirstr, send_to, recv_from)

        call se_up_low4 (dispstr, sind, rind, shift, num_shift, size(data,1), 
     $                   size(data,2), size(data,3), size(data,4))

        send_to_ptr => send_to
        recv_from_ptr => recv_from
        sind_ptr => sind
        rind_ptr => rind

        do sdir = 1, 8

           rdir = mod((sdir + 3), 8) + 1

           if (send_to(sdir) .eq. se_myworker_pe) then

                data(rind(1,1,rdir):rind(2,1,rdir),
     $               rind(1,2,rdir):rind(2,2,rdir),
     $               rind(1,3,rdir):rind(2,3,rdir),
     $               rind(1,4,rdir):rind(2,4,rdir))
     $        = data(sind(1,1,sdir):sind(2,1,sdir),
     $               sind(1,2,sdir):sind(2,2,sdir),
     $               sind(1,3,sdir):sind(2,3,sdir),
     $               sind(1,4,sdir):sind(2,4,sdir))

           else

              if (send_to(sdir) .ge. 0) then
                 call se_data_send (data, sind_ptr, send_to_ptr, sdir, sdir,
     $                              request)
              end if


              if ((recv_from(rdir) .ge. 0) .and.
     $            (recv_from(rdir) .ne. se_myworker_pe)) then
                 call se_data_recv (data, rind_ptr, recv_from_ptr, rdir, sdir)
              end if

c             if (send_to(sdir) .ge. 0) then
c                call mpi_wait (request, status, error)
c             end if

           end if

        end do

	return
        end subroutine se_pe_comm4

C --------------------------------------------------------------------------
C Purpose:
C
C   initialize the lower and upper index of each dimension of a local
C   1-D array
C
C Revision history:
C
C   Orginal version: 9/9/98 by David Wong
C                    11/05/99 by David Wong
C                      -- recode the code using F90 syntax
C                    01/02/03 David Wong
C                      -- modify the code to handle dot file while using dynamic
C                         data allocation
C
C Subroutine parameter description:
C
C   In:  dispstr   -- displacement string
C        shift     -- an array to hold the amount of index shifting due to
C                     starting index is 1 in a subroutine
C        num_shift -- number of shifting
C
C   Out: sind    -- store low and high index of each dimension for sending
C                   process
C        rind    -- store low and high index of each dimension for receiving
C                   process
C
C Local variable description:
C
C    ndis      -- North displacement
C    edis      -- East displacement
C    sdis      -- South displacement
C    wdis      -- West displacement
C    loc_shift -- local adjustment of dummy argument shift
C
C Include file:
C 
C   se_domain_info_ext
C   se_ori_ext
C
C Subroutine/Function call:
C
C   store1 
C
C --------------------------------------------------------------------------

	subroutine se_up_low1 (dispstr, sind, rind, shift, num_shift, dim)

	use se_pe_info_ext
        use se_domain_info_ext
	use se_ori_ext

	implicit none

	integer, intent(out) :: sind(2,8), rind(2,8)
        character (len = 12), intent(in) :: dispstr
        integer, intent(in) :: shift(2), num_shift, dim

	integer :: ndis, edis, sdis, wdis, loc_shift, loc_dim, dot

        if (num_shift .gt. 0) then
           loc_shift = 1 - shift(2)
        else
           loc_shift = 0
        end if

        if (se_geo_ori .eq. 0) then
           read (dispstr, 20) sdis, edis, ndis, wdis
        else
           read (dispstr, 20) ndis, edis, sdis, wdis
        end if
 20     format (4i3)

c       loc_dim = dim - loc_shift
        loc_dim = dim - (ndis + edis + sdis + wdis)

        dot = 0
        if (sdis + ndis .gt. 0) then
           if ((loc_dim .ne. se_my_nrows) .and.
     $         (se_myworker_pe .ge. se_npcol*(se_nprow-1))) then
              dot = 1
           end if
        else
           if ((loc_dim .ne. se_my_ncols) .and.
     $         (mod(se_myworker_pe+1, se_npcol) .eq. 0)) then
              dot = 1
           end if
        end if

C -- ( sending ) determine ghost cells indexes configuration
        if (sdis .gt. 0) then
           call store1 (sind, 1, 1+loc_shift, sdis+loc_shift+dot)
        end if
        if (ndis .gt. 0) then
           call store1 (sind, 5, se_my_nrows-ndis+1+loc_shift, 
     &                  se_my_nrows+loc_shift+dot)
        end if
        if (wdis .gt. 0) then
           call store1 (sind, 3, se_my_ncols-wdis+1+loc_shift, 
     &                  se_my_ncols+loc_shift+dot)
        end if
        if (edis .gt. 0) then
           call store1 (sind, 7, 1+loc_shift, edis+loc_shift+dot)
        end if
 
C -- ( receiving ) determine ghost cells indexes configuration
        if (ndis .gt. 0) then
           call store1 (rind, 1, 1-ndis+loc_shift, loc_shift+dot)
        end if
        if (sdis .gt. 0) then
           call store1 (rind, 5, se_my_nrows+1+loc_shift, 
     &                  se_my_nrows+sdis+loc_shift+dot)
        end if
        if (edis .gt. 0) then
           call store1 (rind, 3, se_my_ncols+1+loc_shift, 
     &                  se_my_ncols+edis+loc_shift+dot)
        end if
        if (wdis .gt. 0) then
           call store1 (rind, 7, 1-wdis+loc_shift, loc_shift+dot)
        end if

	return
	end subroutine se_up_low1

C --------------------------------------------------------------------------
C Purpose:
C
C   to store low and high array indexes of a given domain with ghost cells
C
C Revision history:
C
C   Orginal version: 9/9/98 by David Wong
C                    11/05/99 by David Wong
C                      -- recode the code using F90 syntax
C
C Subroutine parameter description:
C
C   In:  direction -- communication direction
C        i1        -- low index of I dimension
C        i2        -- high index of I dimension
C
C   Out: array     -- array with low and high indexes of each dimension
C --------------------------------------------------------------------------

	subroutine store1 (array, direction, i1, i2)

	integer, intent(out) :: array (2,8) 
        integer, intent(in) :: direction, i1, i2

	  array(1,direction) = i1
	  array(2,direction) = i2

        return
	end subroutine store1

C --------------------------------------------------------------------------
C Purpose:
C
C   initialize the lower and upper index of each dimension of a local
C   2-D array 
C
C Revision history:
C
C   Orginal version: 8/3/98 by David Wong
C                    11/05/99 by David Wong
C                      -- recode the code using F90 syntax
C                    1/17/01 by David Wong
C                      -- use a new function se_corner_adjust to adjust stencil
C                         in the NE, SE, SW, and NW direction of the boundary
C                         processors. The adjustment is applied to the store
C                         function which determine the sending and receiving
C                         indices.
C                    11/28/01 by David Wong
C                      -- make calculation of loc_shift more general to suit
C                         RC orientation.
C                    01/02/03 David Wong
C                      -- modify the code to handle dot file while using dynamic
C                         data allocation
C
C Subroutine parameter description:
C
C   In:  dispstr   -- displacement string
C        shift     -- an array to hold the amount of index shifting due to
C                     starting index is 1 in a subroutine
C        num_shift -- number of shifting
C
C   Out: sind    -- store low and high index of each dimension for sending
C                   process
C        rind    -- store low and high index of each dimension for receiving
C                   process
C
C Local variable description:
C
C    ndis      -- North displacement
C    edis      -- East displacement
C    sdis      -- South displacement
C    wdis      -- West displacement
C    i         -- loop index
C    loc_shift -- local adjustment of dummy argument shift
C
C Include file:
C 
C   se_domain_info_ext
C   se_ori_ext
C
C Subroutine/Function call:
C
C   store2 
C
C --------------------------------------------------------------------------

	subroutine se_up_low2 (dispstr, sind, rind, shift, num_shift,
     $                         dimi, dimj)

        use se_pe_info_ext
	use se_domain_info_ext
	use se_ori_ext
        use se_internal_util_module

	implicit none

	integer, intent(inout) :: sind(2,2,8), rind(2,2,8)
        character (len = 12), intent(in) :: dispstr
        integer, intent(in) :: shift(4), num_shift, dimi, dimj

        integer :: ndis, edis, sdis, wdis, loc_shift(2), i
        integer :: n_adj, e_adj, s_adj, w_adj, dot_c, dot_r, row, col

        if (num_shift .gt. 0) then
           if ((se_data_ori .eq. "cr") .or. (se_data_ori .eq. "CR")) then
              if (shift(1) .eq. 1) then
                 loc_shift(1) = 1 - shift(4)
                 loc_shift(2) = 1 - shift(2)
              else
                 loc_shift(1) = 1 - shift(2)
                 loc_shift(2) = 1 - shift(4)
              end if
           else
              if (shift(1) .eq. 1) then
                 loc_shift(1) = 1 - shift(2)
                 loc_shift(2) = 1 - shift(4)
              else
                 loc_shift(1) = 1 - shift(4)
                 loc_shift(2) = 1 - shift(2)
              end if
           end if
        else
           loc_shift(1) = 0
           loc_shift(2) = 0
        end if

        if (se_geo_ori .eq. 0) then
           read (dispstr, 20) sdis, edis, ndis, wdis
        else
           read (dispstr, 20) ndis, edis, sdis, wdis
        end if
 20     format (4i3)

        if ((se_data_ori .eq. "cr") .or. (se_data_ori .eq. "CR")) then
c          col = dimi - loc_shift(1)
c          row = dimj - loc_shift(2)
           col = dimi - (edis + wdis)
           row = dimj - (ndis + sdis)
        else
c          row = dimi - loc_shift(1)
c          col = dimj - loc_shift(2)
           row = dimi - (ndis + sdis)
           col = dimj - (edis + wdis)
        end if

        dot_c = 0
        if ((col .ne. se_my_ncols) .and.
     $      (mod(se_myworker_pe+1, se_npcol) .eq. 0)) then
           dot_c = 1
        end if

        dot_r = 0
        if ((row .ne. se_my_nrows) .and.
     $      (se_myworker_pe .ge. se_npcol*(se_nprow-1))) then
           dot_r = 1
        end if

        call se_corner_adjust (ndis, edis, sdis, wdis, 1,
     &                         n_adj, e_adj, s_adj, w_adj)

C -- ( sending ) determine ghost cells indexes configuration 
        call store2 (sind, 1, 1+loc_shift(1), sdis+loc_shift(1),
     &               1+loc_shift(2)-w_adj, se_my_ncols+loc_shift(2)+e_adj+dot_c)
        call store2 (sind, 2, 1+loc_shift(1), sdis+loc_shift(1),
     &               se_my_ncols-wdis+1+loc_shift(2), se_my_ncols+loc_shift(2))
        call store2 (sind, 3, 1+loc_shift(1)-n_adj, 
     &               se_my_nrows+loc_shift(1)+s_adj+dot_r,
     &               se_my_ncols-wdis+1+loc_shift(2), se_my_ncols+loc_shift(2))
        call store2 (sind, 4, se_my_nrows-ndis+1+loc_shift(1),
     &               se_my_nrows+loc_shift(1), se_my_ncols-wdis+1+loc_shift(2),
     &               se_my_ncols+loc_shift(2))
        call store2 (sind, 5, se_my_nrows-ndis+1+loc_shift(1),
     &               se_my_nrows+loc_shift(1), 1+loc_shift(2)-w_adj,
     &               se_my_ncols+loc_shift(2)+e_adj+dot_c)
        call store2 (sind, 6, se_my_nrows-ndis+1+loc_shift(1),
     &               se_my_nrows+loc_shift(1), 1+loc_shift(2), 
     &               edis+loc_shift(2))
        call store2 (sind, 7, 1+loc_shift(1)-n_adj, 
     &               se_my_nrows+loc_shift(1)+s_adj+dot_r,
     &               1+loc_shift(2), edis+loc_shift(2))
        call store2 (sind, 8, 1+loc_shift(1), sdis+loc_shift(1),
     &               1+loc_shift(2), edis+loc_shift(2))

        call se_corner_adjust (ndis, edis, sdis, wdis, 2,
     &                         n_adj, e_adj, s_adj, w_adj)

C -- ( receiving ) determine ghost cells indexes configuration 
        call store2 (rind, 1, 1-ndis+loc_shift(1), loc_shift(1),
     &               1+loc_shift(2)-w_adj, se_my_ncols+loc_shift(2)+e_adj+dot_c)
        call store2 (rind, 2, 1-ndis+loc_shift(1), loc_shift(1),
     &               se_my_ncols+1+loc_shift(2), se_my_ncols+edis+loc_shift(2))
        call store2 (rind, 3, 1+loc_shift(1)-n_adj, 
     &               se_my_nrows+loc_shift(1)+s_adj+dot_r, 
     &               se_my_ncols+1+loc_shift(2), se_my_ncols+edis+loc_shift(2))
        call store2 (rind, 4, se_my_nrows+1+loc_shift(1),
     &               se_my_nrows+sdis+loc_shift(1),
     &               se_my_ncols+1+loc_shift(2), se_my_ncols+edis+loc_shift(2))
        call store2 (rind, 5, se_my_nrows+1+loc_shift(1),
     &               se_my_nrows+sdis+loc_shift(1), 1+loc_shift(2)-w_adj,
     &               se_my_ncols+loc_shift(2)+e_adj+dot_c)
        call store2 (rind, 6, se_my_nrows+1+loc_shift(1),
     &               se_my_nrows+sdis+loc_shift(1), 1-wdis+loc_shift(2),
     &               loc_shift(2))
        call store2 (rind, 7, 1+loc_shift(1)-n_adj, 
     &               se_my_nrows+loc_shift(1)+s_adj+dot_r,
     &               1-wdis+loc_shift(2), loc_shift(2))
        call store2 (rind, 8, 1-ndis+loc_shift(1), loc_shift(1),
     &               1-wdis+loc_shift(2), loc_shift(2))

        if ((se_data_ori .eq. "cr") .or. (se_data_ori .eq. "CR")) then
           do i = 1, 8
              call swap (sind(1,1,i), sind(1,2,i))
              call swap (sind(2,1,i), sind(2,2,i))
              call swap (rind(1,1,i), rind(1,2,i))
              call swap (rind(2,1,i), rind(2,2,i))
           end do
        end if

	return
        end subroutine se_up_low2

C --------------------------------------------------------------------------
C Purpose:
C
C   to store low and high array indexes of a given domain with ghost cells
C
C Revision history:
C
C   Orginal version: 7/28/98 by David Wong
C                    11/05/99 by David Wong
C                      -- recode the code using F90 syntax
C
C Subroutine parameter description:
C
C   In:  direction -- communication direction
C        i1        -- low index of I dimension
C        i2        -- high index of I dimension
C        j1        -- low index of J dimension
C        j2        -- high index of J dimension
C
C   Out: array     -- array with low and high indexes of each dimension
C --------------------------------------------------------------------------

	subroutine store2 (array, direction, i1, i2, j1, j2)

	integer, intent(out) :: array (2,2,8) 
        integer, intent(in) :: direction, i1, i2, j1, j2

	  array(1,1,direction) = i1
	  array(2,1,direction) = i2
  	  array(1,2,direction) = j1
	  array(2,2,direction) = j2

        return
	end subroutine store2

C --------------------------------------------------------------------------
C Purpose:
C
C   initialize the lower and upper index of each dimension of a local
C   3-D array
C
C Revision history:
C
C   Orginal version: 8/2/98 by David Wong 
C                    11/05/99 by David Wong
C                      -- recode the code using F90 syntax
C                    1/17/01 by David Wong
C                      -- use a new function se_corner_adjust to adjust stencil
C                         in the NE, SE, SW, and NW direction of the boundary
C                         processors. The adjustment is applied to the store
C                         function which determine the sending and receiving
C                         indices.
C                    11/28/01 by David Wong
C                      -- make calculation of loc_shift more general to suit
C                         RC orientation.
C                    12/04/02 by David Wong
C                      -- modified the routine to accommodate: 1. the
C                         worker and I/O processors partition scheme and 2.
C                         data structure reordering
C                      -- stopped support various spatial decomposition types
C                    01/02/03 David Wong
C                      -- modify the code to handle dot file while using dynamic
C                         data allocation
C                    09/13/04 David Wong
C                      -- used F90 function SIZE to determine the size of the 
C                         third and fourth dimension rather than strictly to
C                         NLVLS and NSPCS, to setup transfer indices, rind and
C                         sind
C
C Subroutine parameter description:
C
C   In:  dispstr   -- displacement string
C        shift     -- an array to hold the amount of index shifting due to
C                     starting index is 1 in a subroutine
C        num_shift -- number of shifting
C
C   Out: sind    -- store low and high index of each dimension for sending
C                   process
C        rind    -- store low and high index of each dimension for receiving
C                   process
C
C Local variable description:
C
C    ndis      -- North displacement
C    edis      -- East displacement
C    sdis      -- South displacement
C    wdis      -- West displacement
C    i         -- loop index
C    loc_shift -- local adjustment of dummy argument shift
C
C Include file:
C
C   se_domain_info_ext
C   se_ori_ext
C
C   se_comm_info_ext
C
C     decompstr -- indicator of which dimenion(s) of data is/are decomposed,
C                  0 (not decomposed), 1 (decomposed)
C
C Subroutine/Function call:
C
C   store3 
C
C --------------------------------------------------------------------------

        subroutine se_up_low3 (dispstr, sind, rind, shift, num_shift,
     $                         dimi, dimj, dimk)

        use se_pe_info_ext
	use se_domain_info_ext
	use se_comm_info_ext
	use se_ori_ext
        use se_internal_util_module

	implicit none

	integer, intent(inout) :: sind(2,3,8), rind(2,3,8)
        character (len = 12), intent(in) :: dispstr
        integer, intent(in) :: shift(6), num_shift, dimi, dimj, dimk

        integer :: ndis, edis, sdis, wdis, loc_shift(3), i
        integer :: dot_c, dot_r
        integer :: n_adj, e_adj, s_adj, w_adj, row, col

        if (num_shift .gt. 0) then
           if ((se_data_ori .eq. "cr") .or. (se_data_ori .eq. "CR")) then
              if (shift(1) .eq. 1) then
                 loc_shift(1) = 1 - shift(4)
                 loc_shift(2) = 1 - shift(2)
              else
                 loc_shift(1) = 1 - shift(2)
                 loc_shift(2) = 1 - shift(4)
              end if
           else
              if (shift(1) .eq. 1) then
                 loc_shift(1) = 1 - shift(2)
                 loc_shift(2) = 1 - shift(4)
              else
                 loc_shift(1) = 1 - shift(4)
                 loc_shift(2) = 1 - shift(2)
              end if
           end if
           loc_shift(3) = 1 - shift(6)
        else
           loc_shift(1:3) = 0
        end if

        if (se_geo_ori .eq. 0) then
           read (dispstr, 20) sdis, edis, ndis, wdis
        else
           read (dispstr, 20) ndis, edis, sdis, wdis
        end if
 20	format (4i3)

        if ((se_data_ori .eq. "cr") .or. (se_data_ori .eq. "CR")) then
c          col = dimi - loc_shift(1)
c          row = dimj - loc_shift(2)
           col = dimi - (edis + wdis)
           row = dimj - (ndis + sdis)
        else
c          row = dimi - loc_shift(1)
c          col = dimj - loc_shift(2)
           row = dimi - (ndis + sdis)
           col = dimj - (edis + wdis)
        end if

        dot_c = 0
        if ((col .ne. se_my_ncols) .and.
     $      (mod(se_myworker_pe+1, se_npcol) .eq. 0)) then
           dot_c = 1
        end if

        dot_r = 0
        if ((row .ne. se_my_nrows) .and.
     $      (se_myworker_pe .ge. se_npcol*(se_nprow-1))) then
           dot_r = 1
        end if

        call se_corner_adjust (ndis, edis, sdis, wdis, 1,
     &                         n_adj, e_adj, s_adj, w_adj)

           call store3 (sind, 1, 1+loc_shift(1), sdis+loc_shift(1), 
     &                  1+loc_shift(2)-w_adj, se_my_ncols+loc_shift(2)+e_adj+dot_c,
     &                  1+loc_shift(3), dimk+loc_shift(3))
           call store3 (sind, 2, 1+loc_shift(1), sdis+loc_shift(1), 
     &                  se_my_ncols-wdis+1+loc_shift(2), 
     &                  se_my_ncols+loc_shift(2), 1+loc_shift(3), 
     &                  dimk+loc_shift(3))
           call store3 (sind, 3, 1+loc_shift(1)-n_adj, 
     &                  se_my_nrows+loc_shift(1)+s_adj+dot_r, 
     &                  se_my_ncols-wdis+1+loc_shift(2), 
     &                  se_my_ncols+loc_shift(2), 1+loc_shift(3), 
     &                  dimk+loc_shift(3))
           call store3 (sind, 4, se_my_nrows-ndis+1+loc_shift(1), 
     &                  se_my_nrows+loc_shift(1), 
     &                  se_my_ncols-wdis+1+loc_shift(2), 
     &                  se_my_ncols+loc_shift(2), 1+loc_shift(3), 
     &                  dimk+loc_shift(3))
           call store3 (sind, 5, se_my_nrows-ndis+1+loc_shift(1), 
     &                  se_my_nrows+loc_shift(1), 1+loc_shift(2)-w_adj, 
     &                  se_my_ncols+loc_shift(2)+e_adj+dot_c, 1+loc_shift(3), 
     &                  dimk+loc_shift(3))
           call store3 (sind, 6, se_my_nrows-ndis+1+loc_shift(1), 
     &                  se_my_nrows+loc_shift(1), 1+loc_shift(2), 
     &                  edis+loc_shift(2), 1+loc_shift(3), 
     &                  dimk+loc_shift(3))
           call store3 (sind, 7, 1+loc_shift(1)-n_adj, 
     &                  se_my_nrows+loc_shift(1)+s_adj+dot_r, 
     &                  1+loc_shift(2), edis+loc_shift(2), 1+loc_shift(3),
     &                  dimk+loc_shift(3))
           call store3 (sind, 8, 1+loc_shift(1), sdis+loc_shift(1), 
     &                  1+loc_shift(2), edis+loc_shift(2), 
     &                  1+loc_shift(3), dimk+loc_shift(3))

        call se_corner_adjust (ndis, edis, sdis, wdis, 2,
     &                         n_adj, e_adj, s_adj, w_adj)

           call store3 (rind, 1, 1-ndis+loc_shift(1), loc_shift(1), 
     &                  1+loc_shift(2)-w_adj, se_my_ncols+loc_shift(2)+e_adj+dot_c, 
     &                  1+loc_shift(3), dimk+loc_shift(3))
           call store3 (rind, 2, 1-ndis+loc_shift(1), loc_shift(1), 
     &                  se_my_ncols+1+loc_shift(2), 
     &                  se_my_ncols+edis+loc_shift(2), 1+loc_shift(3), 
     &                  dimk+loc_shift(3))
           call store3 (rind, 3, 1+loc_shift(1)-n_adj, 
     &                  se_my_nrows+loc_shift(1)+s_adj+dot_r, 
     &                  se_my_ncols+1+loc_shift(2), 
     &                  se_my_ncols+edis+loc_shift(2), 1+loc_shift(3), 
     &                  dimk+loc_shift(3))
           call store3 (rind, 4, se_my_nrows+1+loc_shift(1), 
     &                  se_my_nrows+sdis+loc_shift(1), 
     &                  se_my_ncols+1+loc_shift(2), 
     &                  se_my_ncols+edis+loc_shift(2), 1+loc_shift(3), 
     &                  dimk+loc_shift(3))
           call store3 (rind, 5, se_my_nrows+1+loc_shift(1), 
     &                  se_my_nrows+sdis+loc_shift(1), 1+loc_shift(2)-w_adj, 
     &                  se_my_ncols+loc_shift(2)+e_adj+dot_c, 1+loc_shift(3), 
     &                  dimk+loc_shift(3))
           call store3 (rind, 6, se_my_nrows+1+loc_shift(1), 
     &                  se_my_nrows+sdis+loc_shift(1), 1-wdis+loc_shift(2), 
     &                  loc_shift(2), 1+loc_shift(3), dimk+loc_shift(3))
           call store3 (rind, 7, 1+loc_shift(1)-n_adj, 
     &                  se_my_nrows+loc_shift(1)+s_adj+dot_r, 
     &                  1-wdis+loc_shift(2), loc_shift(2), 1+loc_shift(3), 
     &                  dimk+loc_shift(3))
           call store3 (rind, 8, 1-ndis+loc_shift(1), loc_shift(1), 
     &                  1-wdis+loc_shift(2), loc_shift(2), 1+loc_shift(3), 
     &                  dimk+loc_shift(3))

        if ((se_data_ori .eq. "cr") .or. (se_data_ori .eq. "CR")) then
           do i = 1, 8
              call swap (sind(1,1,i), sind(1,2,i))
              call swap (sind(2,1,i), sind(2,2,i))
              call swap (rind(1,1,i), rind(1,2,i))
              call swap (rind(2,1,i), rind(2,2,i))
           end do
        end if

	return
        end subroutine se_up_low3

C --------------------------------------------------------------------------
C Purpose:
C
C   to store low and high array indexes of a given domain with ghost cells
C
C Revision history:
C
C   Orginal version: 7/28/98 by David Wong
C                    11/05/99 by David Wong
C                      -- recode the code using F90 syntax
C
C Subroutine parameter description:
C
C   In:  direction -- communication direction
C        i1        -- low index of I dimension
C        i2        -- high index of I dimension
C        j1        -- low index of J dimension
C        j2        -- high index of J dimension
C        k1        -- low index of K dimension
C        k2        -- high index of K dimension
C
C   Out: array     -- array with low and high indexes of each dimension
C --------------------------------------------------------------------------

	subroutine store3 (array, direction, i1, i2, j1, j2, k1, k2)

	integer, intent(out) :: array (2,3,8) 
        integer, intent(in) :: direction, i1, i2, j1, j2, k1, k2

	  array(1,1,direction) = i1
	  array(2,1,direction) = i2
  	  array(1,2,direction) = j1
	  array(2,2,direction) = j2
	  array(1,3,direction) = k1
	  array(2,3,direction) = k2

        return
	end subroutine store3

C --------------------------------------------------------------------------
C Purpose:
C
C   initialize the lower and upper index of each dimension of a local
C   4-D array
C
C Revision history:
C
C   Orginal version: 8/3/98 by David Wong
C                    11/05/99 by David Wong
C                      -- recode the code using F90 syntax
C                    1/17/01 by David Wong
C                      -- use a new function se_corner_adjust to adjust stencil
C                         in the NE, SE, SW, and NW direction of the boundary
C                         processors. The adjustment is applied to the store
C                         function which determine the sending and receiving
C                         indices.
C                    11/28/01 by David Wong
C                      -- make calculation of loc_shift more general to suit
C                         RC orientation.
C                    12/04/02 by David Wong
C                      -- modified the routine to accommodate: 1. the
C                         worker and I/O processors partition scheme and 2.
C                         data structure reordering
C                      -- stopped support various spatial decomposition types
C                    01/02/03 David Wong
C                      -- modify the code to handle dot file while using dynamic
C                         data allocation
C                    09/13/04 David Wong
C                      -- used F90 function SIZE to determine the size of the 
C                         third and fourth dimension rather than strictly to
C                         NLVLS and NSPCS, to setup transfer indices, rind and
C                         sind
C
C Subroutine parameter description:
C
C   In:  dispstr   -- displacement string
C        shift     -- an array to hold the amount of index shifting due to
C                     starting index is 1 in a subroutine
C        num_shift -- number of shifting
C
C   Out: sind      -- store low and high index of each dimension for sending
C                     process
C        rind      -- store low and high index of each dimension for receiving
C                     process
C
C Local variable description:
C
C    ndis      -- North displacement
C    edis      -- East displacement
C    sdis      -- South displacement
C    wdis      -- West displacement
C    i         -- loop index
C    loc_shift -- local adjustment of dummy argument shift
C
C Include file:
C
C   se_domain_info_ext
C   se_ori_ext
C
C   se_comm_info.ext
C
C     decompstr -- indicator of which dimenion(s) of data is/are decomposed,
C                  0 (not decomposed), 1 (decomposed)
C
C Subroutine/Function call:
C
C   store4 
C
C --------------------------------------------------------------------------

        subroutine se_up_low4 (dispstr, sind, rind, shift, num_shift,
     $                         dimi, dimj, dimk, diml)

        use se_pe_info_ext
        use se_domain_info_ext
        use se_comm_info_ext
        use se_ori_ext
        use se_internal_util_module

	implicit none

	integer, intent(inout) :: sind(2,4,8), rind(2,4,8)
        character (len = 12), intent(in) :: dispstr
        integer, intent(in) :: shift(8), num_shift, dimi, dimj, dimk, diml

	integer :: ndis, edis, sdis, wdis, loc_shift(4), i
	integer :: col, row, dot_c, dot_r
        integer :: n_adj, e_adj, s_adj, w_adj

        if (num_shift .gt. 0) then
           if ((se_data_ori .eq. "cr") .or. (se_data_ori .eq. "CR")) then
              if (shift(1) .eq. 1) then
                 loc_shift(1) = 1 - shift(4)
                 loc_shift(2) = 1 - shift(2)
              else
                 loc_shift(1) = 1 - shift(2)
                 loc_shift(2) = 1 - shift(4)
              end if
           else
              if (shift(1) .eq. 1) then
                 loc_shift(1) = 1 - shift(2)
                 loc_shift(2) = 1 - shift(4)
              else
                 loc_shift(1) = 1 - shift(4)
                 loc_shift(2) = 1 - shift(2)
              end if
           end if
           loc_shift(3) = 1 - shift(6)
           loc_shift(4) = 1 - shift(8)
        else
           loc_shift(1:4) = 0
        end if

        if (se_geo_ori .eq. 0) then
           read (dispstr, 20) sdis, edis, ndis, wdis
        else
           read (dispstr, 20) ndis, edis, sdis, wdis
        end if
 20	format (4i3)

        if ((se_data_ori .eq. "cr") .or. (se_data_ori .eq. "CR")) then
c          col = dimi - loc_shift(1)
c          row = dimj - loc_shift(2)
           col = dimi - (edis + wdis)
           row = dimj - (ndis + sdis)
        else
c          row = dimi - loc_shift(1)
c          col = dimj - loc_shift(2)
           row = dimi - (ndis + sdis)
           col = dimj - (edis + wdis)
        end if

        dot_c = 0
        if ((col .ne. se_my_ncols) .and.
     $      (mod(se_myworker_pe+1, se_npcol) .eq. 0)) then
           dot_c = 1
        end if

        dot_r = 0
        if ((row .ne. se_my_nrows) .and.
     $      (se_myworker_pe .ge. se_npcol*(se_nprow-1))) then
           dot_r = 1
        end if

        call se_corner_adjust (ndis, edis, sdis, wdis, 1,
     &                         n_adj, e_adj, s_adj, w_adj)

           call store4 (sind, 1, 1+loc_shift(1), sdis+loc_shift(1),
     &                  1+loc_shift(2)-w_adj, se_my_ncols+loc_shift(2)+e_adj+dot_c,
     &                  1+loc_shift(3), dimk+loc_shift(3), 
     &                  1+loc_shift(4), diml+loc_shift(4))
           call store4 (sind, 2, 1+loc_shift(1), sdis+loc_shift(1),
     &                  se_my_ncols-wdis+1+loc_shift(2),
     &                  se_my_ncols+loc_shift(2), 1+loc_shift(3), 
     &                  dimk+loc_shift(3), 1+loc_shift(4), 
     &                  diml+loc_shift(4))
           call store4 (sind, 3, 1+loc_shift(1)-n_adj,
     &                  se_my_nrows+loc_shift(1)+s_adj+dot_r,
     &                  se_my_ncols-wdis+1+loc_shift(2),
     &                  se_my_ncols+loc_shift(2), 1+loc_shift(3), 
     &                  dimk+loc_shift(3), 1+loc_shift(4), 
     &                  diml+loc_shift(4))
           call store4 (sind, 4, se_my_nrows-ndis+1+loc_shift(1), 
     &                  se_my_nrows+loc_shift(1), 
     &                  se_my_ncols-wdis+1+loc_shift(2), 
     &                  se_my_ncols+loc_shift(2), 1+loc_shift(3), 
     &                  dimk+loc_shift(3), 1+loc_shift(4), 
     &                  diml+loc_shift(4))
           call store4 (sind, 5, se_my_nrows-ndis+1+loc_shift(1),
     &                  se_my_nrows+loc_shift(1), 1+loc_shift(2)-w_adj,
     &                  se_my_ncols+loc_shift(2)+e_adj+dot_c, 1+loc_shift(3), 
     &                  dimk+loc_shift(3), 1+loc_shift(4), 
     &                  diml+loc_shift(4))
           call store4 (sind, 6, se_my_nrows-ndis+1+loc_shift(1), 
     &                  se_my_nrows+loc_shift(1), 1+loc_shift(2), 
     &                  edis+loc_shift(2), 1+loc_shift(3), 
     &                  dimk+loc_shift(3), 1+loc_shift(4), 
     &                  diml+loc_shift(4))
           call store4 (sind, 7, 1+loc_shift(1)-n_adj,
     &                  se_my_nrows+loc_shift(1)+s_adj+dot_r,
     &                  1+loc_shift(2), edis+loc_shift(2), 1+loc_shift(3), 
     &                  dimk+loc_shift(3), 1+loc_shift(4), 
     &                  diml+loc_shift(4))
           call store4 (sind, 8, 1+loc_shift(1), sdis+loc_shift(1), 
     &                  1+loc_shift(2), edis+loc_shift(2), 1+loc_shift(3), 
     &                  dimk+loc_shift(3), 1+loc_shift(4), 
     &                  diml+loc_shift(4))

        call se_corner_adjust (ndis, edis, sdis, wdis, 2,
     &                         n_adj, e_adj, s_adj, w_adj)

           call store4 (rind, 1, 1-ndis+loc_shift(1), loc_shift(1),
     &                  1+loc_shift(2)-w_adj, se_my_ncols+loc_shift(2)+e_adj+dot_c,
     &                  1+loc_shift(3), dimk+loc_shift(3), 
     &                  1+loc_shift(4), diml+loc_shift(4))
           call store4 (rind, 2, 1-ndis+loc_shift(1), loc_shift(1), 
     &                  se_my_ncols+1+loc_shift(2), 
     &                  se_my_ncols+edis+loc_shift(2), 1+loc_shift(3), 
     &                  dimk+loc_shift(3), 1+loc_shift(4),
     &                  diml+loc_shift(4))
           call store4 (rind, 3, 1+loc_shift(1)-n_adj,
     &                  se_my_nrows+loc_shift(1)+s_adj+dot_r,
     &                  se_my_ncols+1+loc_shift(2),
     &                  se_my_ncols+edis+loc_shift(2), 1+loc_shift(3), 
     &                  dimk+loc_shift(3), 1+loc_shift(4),
     &                  diml+loc_shift(4))
           call store4 (rind, 4, se_my_nrows+1+loc_shift(1), 
     &                  se_my_nrows+sdis+loc_shift(1), 
     &                  se_my_ncols+1+loc_shift(2), 
     &                  se_my_ncols+edis+loc_shift(2), 1+loc_shift(3), 
     &                  dimk+loc_shift(3), 1+loc_shift(4), 
     &                  diml+loc_shift(4))
           call store4 (rind, 5, se_my_nrows+1+loc_shift(1),
     &                  se_my_nrows+sdis+loc_shift(1), 1+loc_shift(2)-w_adj,
     &                  se_my_ncols+loc_shift(2)+e_adj+dot_c, 1+loc_shift(3), 
     &                  dimk+loc_shift(3), 1+loc_shift(4), 
     &                  diml+loc_shift(4))
           call store4 (rind, 6, se_my_nrows+1+loc_shift(1), 
     &                  se_my_nrows+sdis+loc_shift(1), 1-wdis+loc_shift(2), 
     &                  loc_shift(2), 1+loc_shift(3), dimk+loc_shift(3), 
     &                  1+loc_shift(4), diml+loc_shift(4))
           call store4 (rind, 7, 1+loc_shift(1)-n_adj,
     &                  se_my_nrows+loc_shift(1)+s_adj+dot_r,
     &                  1-wdis+loc_shift(2), loc_shift(2), 1+loc_shift(3), 
     &                  dimk+loc_shift(3), 1+loc_shift(4), 
     &                  diml+loc_shift(4))
           call store4 (rind, 8, 1-ndis+loc_shift(1), loc_shift(1), 
     &                  1-wdis+loc_shift(2), loc_shift(2), 1+loc_shift(3), 
     &                  dimk+loc_shift(3), 1+loc_shift(4), 
     &                  diml+loc_shift(4))

        if ((se_data_ori .eq. "cr") .or. (se_data_ori .eq. "CR")) then
           do i = 1, 8
              call swap (sind(1,1,i), sind(1,2,i))
              call swap (sind(2,1,i), sind(2,2,i))
              call swap (rind(1,1,i), rind(1,2,i))
              call swap (rind(2,1,i), rind(2,2,i))
           end do
        end if

	return
        end subroutine se_up_low4

C --------------------------------------------------------------------------
C Purpose:
C
C   to store low and high array indexes of a given domain with ghost cells
C
C Revision history:
C
C   Orginal version: 7/28/98 by David Wong
C                    11/05/99 by David Wong
C                      -- recode the code using F90 syntax
C
C Subroutine parameter description:
C
C   In:  direction -- communication direction
C        i1        -- low index of I dimension
C        i2        -- high index of I dimension
C        j1        -- low index of J dimension
C        j2        -- high index of J dimension
C        k1        -- low index of K dimension
C        k2        -- high index of K dimension
C        l1        -- low index of L dimension
C        l2        -- high index of L dimension
C
C   Out: array     -- array with low and high indexes of each dimension
C --------------------------------------------------------------------------

	subroutine store4 (array, dir, i1, i2, j1, j2, k1, k2, l1, l2)

	integer, intent(out) :: array (2,4,8) 
        integer, intent(in) :: dir, i1, i2, j1, j2, k1, k2, l1, l2

	  array(1,1,dir) = i1
	  array(2,1,dir) = i2
  	  array(1,2,dir) = j1
	  array(2,2,dir) = j2
	  array(1,3,dir) = k1
	  array(2,3,dir) = k2
	  array(1,4,dir) = l1
	  array(2,4,dir) = l2

        return
	end subroutine store4

        end module se_comm_module
