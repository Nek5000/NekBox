module domain
!     arrays for overlapping Schwartz algorithm
  use kinds, only : DP, i8
  use size_m
  implicit none

  integer, parameter :: ltotd = lx1*ly1*lz1*lelt

  integer :: ndom, n_o, nel_proc, gs_hnd_overlap 
  integer, allocatable :: na(:) , ma(:), nza(:)

!     These are the H1 coarse-grid arrays:
  integer, parameter :: lxc = 2, lcr = lxc**ldim

  integer(i8), allocatable :: se_to_gcrs(:,:)
  integer :: n_crs, m_crs, nx_crs, nxyz_c

  real(DP), allocatable :: h1_basis(:), h1_basist(:)
!  real(DP), pointer :: l2_basis(:),l2_basist(:)
!    equivalence     (h1_basis  ,l2_basis  )
!    equivalence     (h1_basist ,l2_basist )

  contains

  subroutine init_domain()
    use size_m
    implicit none


    allocate(se_to_gcrs(lcr, lelt)) !verified
!    allocate(na(lelt+1), ma(lelt+1), nza(lelt+1))
!    allocate(h1_basis(lx1*lxc), h1_basist(lxc*lx1))


  end subroutine init_domain

end module domain
