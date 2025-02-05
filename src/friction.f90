module friction

  ! This is the only module that needs modifications to implement a new friction law
  ! Follow the instructions in the comment blocks below that start with "! new friction law:"
  !
  ! Assumptions:
  !   The friction coefficient (mu) and the state variable rate (dtheta/dt)
  !   depend on slip velocity (v) and state variable (theta)
  !     mu = f(v,theta)
  !     dtheta/dt = g(v,theta)
  !   All friction properties can be spatially non-uniform

  use problem_class, only : problem_type, tp_type

  implicit none
  private

  public  :: set_theta_star, friction_mu, dmu_dv_dtheta, dtheta_dt

contains

!--------------------------------------------------------------------------------------
subroutine set_theta_star(pb)

  type(problem_type), intent(inout) :: pb
  double precision, dimension(pb%mesh%nn) :: Vw0

  Vw0 = pb%N_con*3.14*pb%a_th*((pb%Tw)/pb%tau_c)**2/pb%Da

  select case (pb%i_rns_law)

  case (0)
    pb%theta_star = pb%dc/pb%v_star

  case (1)
    pb%theta_star = pb%dc/pb%v2

  case (2) ! 2018 SCEC Benchmark
    pb%theta_star = pb%dc/pb%v_star

  case (3) ! SEISMIC: the CNS friction law does not use theta_star
    pb%theta_star = 1

  case (4) ! rsf+fh law (modified by yu)
    !Vw0 = pb%N_con * 3.14 * pb%a_th * (pb%tp%rhoc * (pb%Tw - pb%tp%T_a)/pb%tau_c)**2 / pb%Da 
    !pb%theta_star = exp((log(sinh(((pb%mu_star - pb%fw)/(1 + pb%v_star/Vw0)&
    !+ pb%fw)/pb%a)*2)*pb%a - pb%mu_star)/pb%b)
    pb%theta_star = exp((log(sinh(((pb%mu_star - pb%fw)/(1 + pb%v_star/Vw0)&
    + pb%fw)/pb%a)*2)*pb%a - pb%mu_star)/pb%b)

! new friction law:
!  case(xxx)
!    implement here your definition of theta_star (could be none)
!    pb%theta_star = ...

  case default
    stop 'set_theta_star: unknown friction law type'
  end select

end subroutine set_theta_star

!--------------------------------------------------------------------------------------
function friction_mu(v,theta,pb) result(mu)

  type(problem_type), intent(in) :: pb
  double precision, dimension(pb%mesh%nn), intent(in) :: v, theta
  double precision, dimension(pb%mesh%nn) :: mu

  select case (pb%i_rns_law)

  case (0)
    mu = pb%mu_star - pb%a*log(pb%v_star/v) + pb%b*log(theta/pb%theta_star)

  case (1)
    mu = pb%mu_star - pb%a*log(pb%v1/v+1d0) + pb%b*log(theta/pb%theta_star+1d0)

  case (2) ! SCEC 2018 benchmark
    mu = pb%a*asinh( v/(2*pb%v_star)*exp( (pb%mu_star + pb%b*log(theta/pb%theta_star))/pb%a ) )

  case (3) ! SEISMIC: CNS model
    write (6,*) "friction.f90::friction_mu is deprecated for the CNS model"
    stop

  case (4) ! fh+rsf law (modified by yu)

    mu = pb%a*asinh( v/(2*pb%v_star)*exp( (pb%mu_star + pb%b*log(theta))/pb%a ) )

! new friction law:
!  case(xxx)
!    implement here your friction coefficient: mu = f(v,theta)
!    mu = ...

  case default
    stop 'friction_mu: unknown friction law type'
  end select

end function friction_mu

!--------------------------------------------------------------------------------------
subroutine dtheta_dt(v,tau,sigma,theta,theta2,dth_dt,dth2_dt,pb)

  use friction_cns, only : dphi_dt

  type(problem_type), intent(in) :: pb
  double precision, dimension(pb%mesh%nn), intent(in) :: v, tau, sigma
  double precision, dimension(pb%mesh%nn), intent(in) :: theta, theta2
  double precision, dimension(pb%mesh%nn) :: dth_dt, dth2_dt, omega, theta_ssv
  double precision, dimension(pb%mesh%nn) :: Vw, mu_ssv, omega2

  ! SEISMIC: If the CNS model is selected
  if (pb%i_rns_law == 3) then
    call dphi_dt(v,tau,sigma,theta,theta2,dth_dt,dth2_dt,pb)
  ! SEISMIC: Else, the RSF model is selected (with various theta laws)
  else
    
    if(pb%features%tp == 1) then
      Vw = (pb%N_con * 3.14 * pb%a_th * ( pb%tp%rhoc * (pb%Tw - pb%T )/pb%tau_c ) ** 2)/pb%Da
      mu_ssv = ( pb%a * asinh( v/(2*pb%v_star) * exp((pb%mu_star + pb%b*log(pb%v_star/v))/pb%a) ) - pb%fw )/(1 + (v/Vw)) + pb%fw    
      theta_ssv = exp( (pb%a * log(2*pb%v_star*sinh(mu_ssv/pb%a)/v)-pb%mu_star)/pb%b )
      omega2 = v * (theta_ssv - theta) / pb%dc
    endif
    
    omega = v * theta / pb%dc
    
    select case (pb%itheta_law)

    case(0) ! "aging" in the no-healing approximation
      dth_dt = -omega

    case(1) ! "aging" law
      dth_dt = 1.d0-omega

    case(2) ! "slip" law
      dth_dt = -omega*log(omega)

    case(3) ! For filling the blank (modified by yu)
      dth_dt = -omega*log(omega)

    case(4) ! rsf+fh law (modified by yu)

      !Parameters for flash heating model
      !Vw = pb%N_con * 3.14 * pb%a_th * ( pb%tp%rhoc * (pb%Tw - pb%T )/pb%tau_c ) ** 2 / pb%Da
      !mu_ssv = ( pb%a * asinh( v/(2*pb%v_star) * exp((pb%mu_star + pb%b*log(pb%v_star/v))/pb%a) ) - pb%fw )/(1 + (v - Vw)) + pb%fw    
      !theta_ssv = exp( (pb%a * log(2*pb%v_star*sinh(mu_ssv/pb%a)/v)-pb%mu_star)/pb%b )
      !my state evolution law incorporating rsf+fh: dtheta/dt = g(v, theta)
      !dth_dt = v * (theta_ssv - theta) / pb%dc
      dth_dt = omega2


  ! new friction law:
  !  case(xxx)
  !    implement here your state evolution law: dtheta/dt = g(v,theta)
  !    dth_dt = ...

    case default
      stop 'dtheta_dt: unknown state evolution law type'
    end select

  endif

end subroutine dtheta_dt

!--------------------------------------------------------------------------------------
subroutine dmu_dv_dtheta(dmu_dv,dmu_dtheta,v,theta,pb)

  type(problem_type), intent(in) :: pb
  double precision, dimension(pb%mesh%nn), intent(in) :: v, theta
  double precision, dimension(pb%mesh%nn), intent(out) :: dmu_dv, dmu_dtheta
  double precision :: z(pb%mesh%nn)

  select case (pb%i_rns_law)

  case(0)
    dmu_dtheta = pb%b / theta
    dmu_dv = pb%a / v

  case(1)
    dmu_dtheta = pb%b * pb%v2 / ( pb%v2*theta + pb%dc )
    dmu_dv = pb%a * pb%v1 / v / ( pb%v1 + v )

  case(2) ! 2018 SCEC Benchmark
    z = exp((pb%mu_star + pb%b * log(theta/pb%theta_star)) / pb%a) / (2*pb%v_star)
    dmu_dv = pb%a / sqrt(1.0/z**2 + v**2)
    dmu_dtheta = dmu_dv * (pb%b*v) / (pb%a*theta)

  case(3) ! SEISMIC: CNS model
    write (6,*) "friction.f90::dmu_dv_dtheta is deprecated for the CNS model"
    stop

  case(4) ! for filling the blank(need confirmation)
    z = exp((pb%mu_star + pb%b * log(theta)) / pb%a) / (2*pb%v_star)
    dmu_dv = pb%a / sqrt(1.0/z**2 + v**2)
    dmu_dtheta = dmu_dv * (pb%b*v) / (pb%a*theta)

  case default
    write (6,*) "dmu_dv_dtheta: unkown friction law type"
    stop
  end select

end subroutine dmu_dv_dtheta

end module friction
