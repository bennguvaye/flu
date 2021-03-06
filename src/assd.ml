(* Simulate the single-strain age-structured ODE system using Dopri5 *)
open Lacaml.D;;

let pi = 4. *. atan 1.;;

module type PARS =
  sig
    val a : int
    val size : float
    val r0 : float
    val e : float
    val etaN : float
    val g : float
    val nu : float
    val sensi_v : Lacaml_float64.vec
    val prop_v : Lacaml_float64.vec
    val cont_m : Lacaml_float64.mat
    val init_perturb : float
    val dilat_bound : float
  end;;

module Sys (Pars : PARS) : Dopri5.SYSTEM =
  struct
    open Pars;;
  
    assert (size >= 0. 
         && r0 >= 0. 
         && e >= 0. 
         && etaN >= 0. 
         && g >= 0. 
         && nu >= 0.
         && init_perturb > 0. 
         && dilat_bound > 0.);;

    assert (a = Mat.dim1 cont_m 
         && a = Mat.dim2 cont_m
         && a = Vec.dim sensi_v 
         && a = Vec.dim prop_v);;

    let eta = etaN *. size
    let bet0 = r0 *. nu

    let n = 3 * a * 2
    let m = 1

    let eta_v = Vec.make a eta;;
    (* prop_v will contain the number of hosts in each age class (and not the proportion) *)
    scal size prop_v 

    (* initialize the jacobian *)
    let jac_m = Mat.make0 (n / 2) (n / 2);;(* jacobian *)
    for k = 1 to a do
      (* s_k against r_k *)
      jac_m.{k, 2 * a + k} <- g ;
      (* r_k agains r_k *)
      jac_m.{2 * a + k, 2 * a + k} <- ~-. g ;
      (* r_k against i_k *)
      jac_m.{2 * a + k, a + k} <- nu
    done

    (* allocate stuff *)
    let s_v = Vec.make0 a
    let i_v = Vec.make0 a
    let r_v = Vec.make0 a
    let beta_i = Vec.make0 a
    let beta_s = Vec.make0 a
    let s_dot_v = Vec.make0 a
    let i_dot_v = Vec.make0 a
    let r_dot_v = Vec.make0 a

    let dx = Vec.make0 (n / 2) (* the ds, di, dr values *)

    let tmp_x = Vec.make0 (n / 2)
    let tmp_dx = Vec.make0 (n / 2)
    let tmp_a1 = Vec.make0 a
    let tmp_a2 = Vec.make0 a

    let f ?(z=Vec.make0 n) t y =
      let s_v = copy ~y:s_v ~ofsx:1 ~n:a y in
      let i_v = copy ~y:i_v ~ofsx:(a + 1) ~n:a y in
      let r_v = copy ~y:r_v ~ofsx:(2 * a + 1) ~n:a y in
      (* r values are always used times g *)
      scal g r_v ;
      let beta = bet0 *. (1. +. e *. cos (2. *. pi *. t /. 365.)) in
      let tmp_a2 = copy ~y:tmp_a2 sensi_v in
      scal beta tmp_a2 ; (* tmp_m2 now contains infectivities for each age class *)
      let tmp_a2 = Vec.div ~z:tmp_a2 tmp_a2 prop_v in
      (* tmp_a2 now contains the per infectious per susceptible infectivity *)
      let tmp_a1 = copy ~y:tmp_a1 eta_v in (* fill tmp_a with eta *)
      (* compute the number of contacts : matrix of contacts * each number of infected *)
      let tmp_a1 = gemv ~y:tmp_a1 ~beta:1. ~m:a cont_m i_v in
      (* compute the "per susceptible" number of infections *)
      let beta_i = Vec.mul ~z:beta_i tmp_a1 tmp_a2 in
      (* compute the "per infectious" number of infections *)
      let beta_s = Vec.mul ~z:beta_s tmp_a2 s_v in
      (* compute the total number of infections *)
      let infct = Vec.mul ~z:tmp_a1 beta_i s_v in (* stored in tmp_m1 ! *)
      let s_dot_v = Vec.sub ~z:s_dot_v r_v infct in
      (* we only need i values times nu now *)
      scal nu i_v ;
      let i_dot_v = Vec.sub ~z:i_dot_v infct i_v in
      let r_dot_v = Vec.sub ~z:r_dot_v i_v r_v in

      (* update the values in the jacobian *)      
      (* maybe find more efficient than these loops... *)
      for k = 1 to a do
        (* s_k against s_k *)
        jac_m.{k, k} <- ~-. (beta_i.{k}) ;
        (* i_k against s_k *)
        jac_m.{a + k, k} <- beta_i.{k} ;
        for l = 1 to a do
          let beta_s_kl = beta_s.{k} *. cont_m.{k, l} in
          (* s_k agains i_l *)
          jac_m.{k, a + l} <- ~-. beta_s_kl ;
          (* i_k agains i_l *)
          if k = l then
            jac_m.{a + k, a + l} <- beta_s_kl -. nu 
          else
            jac_m.{a + k, a + l} <- beta_s_kl ;
        done
      done ;

      let dx = copy ~y:dx ~n:(n/2) ~ofsx:(1 + n/2) y in
      let tmp_dx = gemv ~alpha:1. ~beta:0. ~y:tmp_dx jac_m dx in
      (* we copy the computed values for the base system to z *)
      let z = copy ~y:z ~ofsy:1 s_dot_v in
      let z = copy ~y:z ~ofsy:(a + 1) i_dot_v in
      let z = copy ~y:z ~ofsy:(2 * a + 1) r_dot_v in
      (* we copy the computed values for the variational system to z *)
      let z = copy ~y:z ~ofsy:(1 + n/2) tmp_dx in
      z

    let aux ?(z=Vec.make0 m) t y =
      let beta = bet0 *. (1. +. e *. cos (2. *. pi *. t /. 365.)) in
      let s_v = copy ~y:s_v ~ofsx:1 ~n:a y in
      let i_v = copy ~y:i_v ~ofsx:(a + 1) ~n:a y in
      let tmp_a2 = copy ~y:tmp_a2 sensi_v in
      scal beta tmp_a2 ; (* tmp_a2 now contains infectivities for each age class *)
      let tmp_a2 = Vec.div ~z:tmp_a2 tmp_a2 prop_v in
      (* tmp_a2 now contains the per infectious per susceptible infectivity *)
      let tmp_a1 = copy ~y:tmp_a1 eta_v in (* fill tmp_a with eta *)
      (* compute the number of contacts : matrix of contacts * each number of infected *)
      let tmp_a1 = gemv ~y:tmp_a1 ~beta:1. ~m:a cont_m i_v in
      (* compute the "per susceptible" number of infections *)
      let beta_i = Vec.mul ~z:beta_i tmp_a1 tmp_a2 in
      (* compute the "per infectious" number of infections *)
      let infct = Vec.mul ~z:tmp_a1 beta_i s_v in (* stored in tmp_a1 ! *)
      scal (7. *. 100000. /. size) infct ;
      (* Weekly incidence for 100 000 *)
      z.{1} <- Vec.sum infct ;
      z

    let norm1_var y =
      let dx = copy ~y:dx ~n:(n/2) ~ofsx:(1 + n/2) y in
      amax dx

    let norm2_var y =
      let dx = copy ~y:dx ~n:(n/2) ~ofsx:(1 + n/2) y in
      sqrt (dot dx dx)
    
    let check_in_domain y =
      if Vec.min ~n:(n/2) y < 0. then false else 
      if norm2_var y > init_perturb *. dilat_bound then false else
      true

    let shift_in_domain ?(z=Vec.make0 n) y =   
      for i = 1 to (n/2) do
        if y.{i} < 0. then
          let d = y.{i} /. (float_of_int (n/2 - 1)) in
          for j = 1 to (i - 1) do
            z.{j} <- y.{j} +. d
          done;
          for j = (i + 1) to (n/2) do
            z.{j} <- y.{j} +. d
          done;
          z.{i} <- 0.;
      done;  
      let nrm = norm2_var y in
      if nrm > init_perturb *. dilat_bound then
        for i = (1 + n/2) to n do
          z.{i} <- y.{i} *. init_perturb /. nrm
        done ;
      z

    let csv_init () =
      let rec f s n s_l =
        match n > 0 with
        | true -> 
            f s (n - 1) ((s ^ string_of_int n) :: s_l)
        | false -> 
            s_l
      in
      ["t" ; "h" ; "inc"] 
      @ List.concat
      (List.map (fun s -> f s a []) ["S_" ; "I_" ; "R_" ; 
                                     "dS_" ; "dI_" ; "dR_" ])
  end;;

module Default_Algp =
  struct
    let h0 = 1. /. (24. *. 60.);;
    let delta = 0.1;; (* an error of 0.1 person seems ok *)
    let min_step = 1. /. (24. *. 3600.);; (* more than one step a second looks overkill *)
    let max_step = 1.;; (* we always want at least a resolution of a day *)
  end;;


