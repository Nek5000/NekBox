!> cleaned
module parallel
!     Communication information
!     NOTE: NID is stored in 'SIZE' for greater accessibility
  use size_m, only : nid
  implicit none

  INTEGER ::        NODE,PID,NP,NULLPID,NODE0

!     Maximum number of elements (limited to 2**31/12, at least for now)
  !integer, parameter :: NELGT_MAX = 178956970

  integer, allocatable :: nelg(:) 
  integer :: nvtot, nelgv, nelgt

  LOGICAL :: IFGPRNT
  INTEGER :: WDSIZE,ISIZE,LSIZE,CSIZE,WDSIZI
  LOGICAL :: IFDBLAS

!     crystal-router, gather-scatter, and xxt handles (xxt=csr grid solve)

  integer :: cr_h, gsh
  integer, allocatable :: gsh_fld(:), xxth(:)

  integer :: nekcomm, nekgroup, nekreal

  ! map information
  integer, private :: queue_dim(30)
  integer, private :: queue_fac(30)
  integer, private :: queue_div(30)
  integer, private :: num_queue
  integer :: proc_pos(3) 
  integer :: proc_shape(3)

  integer, private :: queue_dim_e(30)
  integer, private :: queue_fac_e(30)
  integer, private :: queue_div_e(30)
  integer, private :: num_queue_e

  contains

  subroutine init_parallel()
    use size_m
    implicit none

    allocate(NELG(0:LDIMT1))
    allocate(gsh_fld(0:ldimt3), xxth(ldimt3))

  end subroutine init_parallel

  subroutine init_gllnid()
    use mesh, only : shape_x
    use size_m, only : lelt
    use input, only : param
    implicit none

    integer :: i, l, iel, ieg
    integer :: np_targ
    integer :: my_shape(3), my_nid
    integer :: factors(30), num_fac
    integer :: factors2(30), num_fac2
    integer :: largest_idx
    integer :: queue_pos

    factors = -1
    np_targ = np
    num_fac = 0
    do while (np_targ > 1)
      do i = 2, np_targ
        if ((np_targ / i) * i == np_targ) then
          num_fac = num_fac + 1
          factors(num_fac) = i
          np_targ = np_targ / i
          exit
        endif
      enddo
    enddo

    my_shape = shape_x
    num_queue = 0
    num_fac2 = 0
    do while (num_fac > 0) 
      largest_idx = 3
      if (my_shape(2) > my_shape(largest_idx)) largest_idx = 2
      if (my_shape(1) > my_shape(largest_idx)) largest_idx = 1

      if ((my_shape(largest_idx) / factors(num_fac)) * factors(num_fac) /= my_shape(largest_idx)) then
          num_fac2 = num_fac2 + 1
          factors2(num_fac2) = factors(num_fac)
      else
          my_shape(largest_idx) = my_shape(largest_idx) / factors(num_fac)
          num_queue = num_queue + 1
          queue_dim(num_queue) = largest_idx
          queue_fac(num_queue) = factors(num_fac)
          queue_div(num_queue) = my_shape(largest_idx)
      endif
      num_fac = num_fac - 1
    enddo

    do while (num_fac2 > 0) 
      largest_idx = 3
      if (my_shape(2) > my_shape(largest_idx)) largest_idx = 2
      if (my_shape(1) > my_shape(largest_idx)) largest_idx = 1

      if ((my_shape(largest_idx) / factors2(num_fac2)) * factors2(num_fac2) == my_shape(largest_idx)) then
          my_shape(largest_idx) = my_shape(largest_idx) / factors2(num_fac2)
          num_queue = num_queue + 1
          queue_dim(num_queue) = largest_idx
          queue_fac(num_queue) = factors2(num_fac2)
          queue_div(num_queue) = my_shape(largest_idx)
      else if ((my_shape(1) / factors2(num_fac2)) * factors2(num_fac2) == my_shape(1)) then
          my_shape(1) = my_shape(1) / factors2(num_fac2)
          num_queue = num_queue + 1
          queue_dim(num_queue) = 1
          queue_fac(num_queue) = factors2(num_fac2)
          queue_div(num_queue) = my_shape(1)
      else if ((my_shape(2) / factors2(num_fac2)) * factors2(num_fac2) == my_shape(2)) then
          my_shape(2) = my_shape(2) / factors2(num_fac2)
          num_queue = num_queue + 1
          queue_dim(num_queue) = 2
          queue_fac(num_queue) = factors2(num_fac2)
          queue_div(num_queue) = my_shape(2)
      else if ((my_shape(3) / factors2(num_fac2)) * factors2(num_fac2) == my_shape(3)) then
          my_shape(1) = my_shape(3) / factors2(num_fac2)
          num_queue = num_queue + 1
          queue_dim(num_queue) = 3
          queue_fac(num_queue) = factors2(num_fac2)
          queue_div(num_queue) = my_shape(3)
      else
        write(*,*) "Warning: processes don't divide mesh"
      endif
      num_fac2 = num_fac2 - 1
    enddo


    proc_shape = my_shape

    proc_pos = 0
    my_nid = nid
    do queue_pos = num_queue, 1, -1
      l = queue_dim(queue_pos) 
      proc_pos(l) = proc_pos(l) + mod(my_nid, queue_fac(queue_pos)) * my_shape(l)
      my_shape(l) = my_shape(l) * queue_fac(queue_pos)
      my_nid = my_nid / queue_fac(queue_pos)
    enddo


!==========================================
    my_shape = proc_shape
    factors = -1
    np_targ = my_shape(1) * my_shape(2) * my_shape(3)
    num_fac = 0
    do while (np_targ > 1)
      do i = 2, np_targ
        if ((np_targ / i) * i == np_targ) then
          num_fac = num_fac + 1
          factors(num_fac) = i
          np_targ = np_targ / i
          exit
        endif
      enddo
    enddo

    num_queue_e = 0
    num_fac2 = 0
    do while (num_fac > 0) 
      largest_idx = 3
      if (my_shape(2) > my_shape(largest_idx)) largest_idx = 2
      if (my_shape(1) > my_shape(largest_idx)) largest_idx = 1

      if ((my_shape(largest_idx) / factors(num_fac)) * factors(num_fac) /= my_shape(largest_idx)) then
          num_fac2 = num_fac2 + 1
          factors2(num_fac2) = factors(num_fac)
      else
          my_shape(largest_idx) = my_shape(largest_idx) / factors(num_fac)
          num_queue_e = num_queue_e + 1
          queue_dim_e(num_queue_e) = largest_idx
          queue_fac_e(num_queue_e) = factors(num_fac)
          queue_div_e(num_queue_e) = my_shape(largest_idx)
      endif
      num_fac = num_fac - 1
    enddo

    do while (num_fac2 > 0) 
      largest_idx = 3
      if (my_shape(2) > my_shape(largest_idx)) largest_idx = 2
      if (my_shape(1) > my_shape(largest_idx)) largest_idx = 1

      if ((my_shape(largest_idx) / factors2(num_fac2)) * factors2(num_fac2) == my_shape(largest_idx)) then
          my_shape(largest_idx) = my_shape(largest_idx) / factors2(num_fac2)
          num_queue_e = num_queue_e + 1
          queue_dim_e(num_queue_e) = largest_idx
          queue_fac_e(num_queue_e) = factors2(num_fac2)
          queue_div_e(num_queue_e) = my_shape(largest_idx)
      else if ((my_shape(1) / factors2(num_fac2)) * factors2(num_fac2) == my_shape(1)) then
          my_shape(1) = my_shape(1) / factors2(num_fac2)
          num_queue_e = num_queue_e + 1
          queue_dim_e(num_queue_e) = 1
          queue_fac_e(num_queue_e) = factors2(num_fac2)
          queue_div_e(num_queue_e) = my_shape(1)
      else if ((my_shape(2) / factors2(num_fac2)) * factors2(num_fac2) == my_shape(2)) then
          my_shape(2) = my_shape(2) / factors2(num_fac2)
          num_queue_e = num_queue_e + 1
          queue_dim_e(num_queue_e) = 2
          queue_fac_e(num_queue_e) = factors2(num_fac2)
          queue_div_e(num_queue_e) = my_shape(2)
      else if ((my_shape(3) / factors2(num_fac2)) * factors2(num_fac2) == my_shape(3)) then
          my_shape(1) = my_shape(3) / factors2(num_fac2)
          num_queue_e = num_queue_e + 1
          queue_dim_e(num_queue_e) = 3
          queue_fac_e(num_queue_e) = factors2(num_fac2)
          queue_div_e(num_queue_e) = my_shape(3)
      else
        write(*,*) "Warning: processes don't divide mesh"
      endif
      num_fac2 = num_fac2 - 1
    enddo

    if (param(75) < 1) then
    do iel = 1, lelt
      ieg = lglel(iel)
      if (gllnid(ieg) /= nid .or. gllel(ieg) /= iel) then
        write(*,*) "LGL/GLL mismatch", nid, gllnid(ieg), iel, gllel(ieg) 
      endif
    enddo
    if (nid == 0) write(*,*) "LGL/GLL checks out"
    endif

  end subroutine init_gllnid

  integer function gllnid(ieg)
    use mesh, only : ieg_to_xyz
    implicit none
    integer, intent(in) :: ieg

    integer :: queue_pos
    integer :: ix(3) 

    ix = ieg_to_xyz(ieg)
    gllnid = 0
    do queue_pos = 1, num_queue
      gllnid = queue_fac(queue_pos) * gllnid + ix(queue_dim(queue_pos)) / queue_div(queue_pos)
      ix(queue_dim(queue_pos)) = mod(ix(queue_dim(queue_pos)), queue_div(queue_pos))
    enddo

    return
  end function gllnid

  logical function my_ieg(ieg)
    use mesh, only : ieg_to_xyz
    integer, intent(in) :: ieg    

    integer, save :: my_seq(30) = -1
    integer :: ix(3)
    integer :: queue_pos

    if (my_seq(1) < 0) then
      ix = ieg_to_xyz(lglel(1)) 
      do queue_pos = 1, num_queue
        my_seq(queue_pos) = ix(queue_dim(queue_pos)) / queue_div(queue_pos)
        ix(queue_dim(queue_pos)) = mod(ix(queue_dim(queue_pos)), queue_div(queue_pos))
      enddo
    endif

    ix = ieg_to_xyz(ieg)
    do queue_pos = 1, num_queue
      if (my_seq(queue_pos) /= ix(queue_dim(queue_pos)) / queue_div(queue_pos)) then
        my_ieg = .false.
        return
      endif
      ix(queue_dim(queue_pos)) = mod(ix(queue_dim(queue_pos)), queue_div(queue_pos))
    enddo

    my_ieg = .true.
    return
  end function my_ieg

  integer function gllel(ieg)
    use mesh, only : ieg_to_xyz
    implicit none
    integer, intent(in) :: ieg

    integer :: ix(3) , queue_pos
    ix = ieg_to_xyz(ieg)
    ix(1) = mod(ix(1), proc_shape(1))
    ix(2) = mod(ix(2), proc_shape(2))
    ix(3) = mod(ix(3), proc_shape(3))
    
    gllel = 0
    do queue_pos = 1, num_queue_e
      gllel = queue_fac_e(queue_pos) * gllel + ix(queue_dim_e(queue_pos)) / queue_div_e(queue_pos)
      ix(queue_dim_e(queue_pos)) = mod(ix(queue_dim_e(queue_pos)), queue_div_e(queue_pos))
    enddo
    gllel = gllel + 1

    return
  end function gllel

  integer function lglel(iel)
    use mesh, only : xyz_to_ieg
    implicit none
    integer, intent(in) :: iel

    integer :: my_pos(3), l_pos(3), idx, l, my_shape(3), queue_pos

    l_pos = 0
    my_shape = 1
    idx = iel-1
    do queue_pos = num_queue_e, 1, -1
      l = queue_dim_e(queue_pos)
      l_pos(l) = l_pos(l) + mod(idx, queue_fac_e(queue_pos)) * my_shape(l)
      my_shape(l) = my_shape(l) * queue_fac_e(queue_pos)
      idx = idx / queue_fac_e(queue_pos)
    enddo

    my_pos = proc_pos + l_pos

    lglel = xyz_to_ieg(my_pos)
    return

  end function lglel

end module parallel

