open Lacaml.D

let change_chan_to_file co_r s =
  co_r := open_out s

let load_vec_from_file v_r fname =
  let data = Csv.load fname in
  match data with
  | [] -> 
      failwith "no data read from file"
  | l1 :: l2 :: _ -> 
      failwith "file has more than one line"
  | l1 :: [] ->
      let l = List.map (fun s -> float_of_string s) l1 in
      let v = Vec.of_list l in
      v_r := v

let load_mat_from_file m_r fname =
  let f s_l =
    List.map (fun s -> float_of_string s) s_l
  in
  let g s_l =
    match s_l with
    | [] -> failwith "empty line"
    | s :: tl -> List.map (fun s -> float_of_string s) tl
  in
  let data = Csv.load fname in
  match data with
  | [] -> 
      failwith "no data read from file"
  | (s :: []) :: [] -> 
    let m = Mat.make 1 1 (float_of_string s) in m_r := m
  | l1 :: [] ->
      failwith "file has only one line"
  | l1 :: ltl ->
      let ll =
        (try List.map f data with
        | Failure _ -> List.map g ltl)
        (*let ll = List.map 
          (fun l -> List.map (fun s -> float_of_string s) l) data in*)
      in
      let m = Mat.of_array 
          (Array.of_list (List.map (fun l -> Array.of_list l) ll))
      in m_r := m

(* system parameter values *)
let size_r = ref (100000.)
let r0_r = ref (2.)
let e_r = ref (0.15)
let g_r = ref (1. /. (10. *. 365.))
let nu_r = ref (1. /. 2.77)

(* Theoretical parameter set *)
(*
let size_r = ref (10. ** 5.)
let r0_r = ref (5.)
let e_r = ref (0.35)
let etaN1_r = ref (10. ** (-.7.))
let etaN2_r = ref (10. ** (-.7.))
let g_r = ref (1. /. (20. *. 365.))
let nu_r = ref (1. /. 8.) 
*)

(* variational system behaviour *)
let init_perturb_r = ref (10. ** (~-. 8.))
let dilat_bound_r = ref 10.

(* simulation arguments *)
let tf_r = ref (365. *. 200.)

(* FIXME initialize all that later in file ? *)
(* FIXME find the right values *)
(* FIXME problem if the user changes one but not the other *)
let a_r = ref 3
let age_prop_r = ref (Vec.of_array
              [| 0.25 ; 0.54 ; 0.21 |]) (* data for Paris *)

let sensi_r = ref (Vec.of_array
              [| 1. ; 1. ; 1. |]) (* what do we use ? *) 

(* We use as values the Mij.dat generated by age.r even if it's maybe incorrect *)
(* reason why : no conservation of the dominant eigenvalue after transformation *)
let cont_r =
  let cont_r_base = Mat.of_array
              [| 
                [| 13.747 ; 5.037 ; 1.846 |] ;
                [| 5.037  ; 8.665 ; 4.041 |] ; 
                [| 1.846  ; 4.041 ; 7.747 |] 
              |]
  in
  (* We normalize it by its dominant eigenvalue so that the mean number 
   of secondary contacts is 1 *)
  (*
  Mat.scal (1. /. 18.21203416) cont_r_base ;
  *)
  ref cont_r_base

let c_r = ref 3
let eta_r = ref (Mat.make0 !c_r !c_r) ;;
load_mat_from_file eta_r "../../data/eta_dummy.csv"

let city_prop_r = ref (Vec.make0 !c_r) ;;
load_vec_from_file city_prop_r "../../data/city_prop_dummy.csv"

let x0 = Vec.of_array 
           [| 0.5 ; 0.001 ; 0.499 |]

(* Algorithm parameters *)
let h0_r = ref (1. /. (24. *. 60.))
let delta_r = ref 0.1
let min_step_r = ref (1. /. (24. *. 3600.))
let max_step_r = ref 1.;;

let main () =
  let chan_r = ref stdout in
  let specx0 = 
        [Arg.Float (fun x -> x0.{1} <- x);
         Arg.Float (fun x -> x0.{2} <- x);
         Arg.Float (fun x -> x0.{3} <- x)] in
  let specl = 
        [("-dest", Arg.String (change_chan_to_file chan_r),
                ": location of the destination CSV file.\n" ^ 
                "      If not given, outputs to standard output.");
         ("-tf", Arg.Set_float tf_r,
                ": Simulate until (in days)");
         ("-y0", Arg.Tuple specx0,
                ": Initial proportions in each compartment (Should sum to 1)");
         ("-a", Arg.Set_int a_r,
                ": Number of age classes (default 3)");
         ("-c", Arg.Set_int c_r,
                ": Number of cities (default 260)");
         ("-N", Arg.Set_float size_r, 
                ": Total number of hosts in the population");
         ("-R0", Arg.Set_float r0_r, 
                ": Basic reproductive ratio");
         ("-e", Arg.Set_float e_r, 
                ": Strength of the seasonal forcing");
         ("-g", Arg.Set_float g_r, 
                ": Frequency of immunity loss (1/days)");
         ("-nu", Arg.Set_float nu_r, 
                ": Frequency of recovery from infection (1/days)");
         ("-faprop", Arg.String (load_vec_from_file age_prop_r),
                " : File location of the proportions of age classes");
         ("-fsensi", Arg.String (load_vec_from_file sensi_r),
                ": File location of the sensibilities for each age class");
         ("-fcont", Arg.String (load_mat_from_file cont_r),
                ": File location of the contact matrix between age classes");
         ("-fcprop", Arg.String (load_vec_from_file city_prop_r),
                " : File location of the proportions of city sizes");
         ("-feta", Arg.String (load_mat_from_file eta_r),
                ": File location of the airflow traffic matrix");
         ("-init_perturb", Arg.Set_float init_perturb_r,
                ": Initial norm (1) of the perturbation");
         ("-dil", Arg.Set_float dilat_bound_r, 
                ": Dilatation factor before rescaling the variational system");
         ("-h0", Arg.Set_float h0_r,
                ": Initial step size");
         ("-delta", Arg.Set_float delta_r,
                ": Maximum tolerated local error. Must be > 0.");
         ("-min_step", Arg.Set_float min_step_r,
                ": Minimum resolution in time. Must be > 0.");
         ("-max_step", Arg.Set_float max_step_r,
                ": Maximum resolution in time. Must be > 0.")]
  in
  (* simply ignore anonymous arguments *)
  let anon_print s = print_endline ("Ignored anonymous argument : " ^ s) in
  (* printed before the help message : *)
  let usage_msg = "  Simulate using Dopri5(.ml) a single strain " ^
                  "seasonally forced SIR model approximating (for example) " ^
                  "influenza dynamics." ^
                  "\nFor more info, look into ssd.mli and dopri5.mli.\n" ^
                  "Available options :" in
  (* parse the command line and update the parameter values *)
  Arg.parse specl anon_print usage_msg ;

  (*** Sanity check ***)
  (* Dimensions *)
  if not (!a_r = Vec.dim !age_prop_r) then
    (failwith "Dimensions are not compatible : a and faprop") ;
  if not (!c_r = Vec.dim !city_prop_r) then
    (failwith "Dimensions are not compatible : c and fcprop") ;
  (* Proportions sum to 1 *)
  if (1. -. 10. ** (~-. !size_r -. 1.)  < Vec.sum ~n:(!a_r) !age_prop_r) 
  && (Vec.sum ~n:(!a_r)  !age_prop_r < 1. -. 10. ** (~-. !size_r -. 1.))  
  then 
    (failwith 
     "The user did not pass a proportion tuple (sums to 1) as faprop : \n") ;
  if (1. -. 10. ** (~-. !size_r -. 1.)  < Vec.sum ~n:(!c_r) !city_prop_r) 
  && (Vec.sum ~n:(!c_r)  !city_prop_r < 1. -. 10. ** (~-. !size_r -. 1.))  
  then 
    (failwith  
     "The user did not pass a proportion tuple (sums to 1) as fcprop : \n") ;
  if (1. -. 10. ** (~-. !size_r -. 1.)  < Vec.sum ~n:3 x0) 
  && (Vec.sum ~n:3 x0 < 1. -. 10. ** (~-. !size_r -. 1.))  
  then 
    (failwith 
     "The user did not pass a proportion tuple (sums to 1) as x0 : \n") ;
  (* We scale the population size appropriately *)
  scal ~n:3 ~ofsx:1 !size_r x0 ;
  (* We create the perturbation and scale it *)
  let f = fun n -> Random.float 2. -. 1. in
  let rdu = Array.init (3 * !a_r * !c_r) f in
  let s = Array.fold_left (+.) 0. rdu in
  let dx0 = Vec.of_array (Array.map (fun x -> (x -. s)) rdu) in
  scal ~n:(3 * !a_r) ~ofsx:1 !init_perturb_r dx0 ;
  let y0 = Vec.make0 (3 * 2 * !a_r * !c_r) in
  for i = 1 to !c_r do
    for k = 1 to !a_r do
      (ignore (copy 
                 ~n:3 
                 ~ofsy:(1 + 3 * !a_r * (i - 1) + 3 * (k - 1)) 
                 ~y:y0 
                 x0) ;
        scal 
          ~n:3 
          ~ofsx:(1 + 3 * !a_r * (i - 1) + 3 * (k - 1)) 
          ((!age_prop_r).{k} *. (!city_prop_r).{i}) y0)
    done
  done ;
  let y0 = copy ~n:(3 * !c_r * !a_r) ~y:y0 ~ofsy:(1 + 3 * !c_r * !a_r) dx0 in
  let module Pars = 
    struct
      let a = !a_r
      let c = !c_r
      let size = !size_r
      let r0 = !r0_r
      let e = !e_r
      let g = !g_r
      let nu = !nu_r
      let sensi_base_v = !sensi_r
      let age_prop_v = !age_prop_r
      let cont_base_m = !cont_r
      let eta_base_m = !eta_r
      let city_prop_v = !city_prop_r
      let init_perturb = !init_perturb_r
      let dilat_bound = !dilat_bound_r
    end
  in
  let module CassdSys = Cassd.Sys (Pars) in
  let module Algp =
    struct
      let h0 = !h0_r
      let delta = !delta_r
      let min_step = !min_step_r
      let max_step = !max_step_r
    end
  in
  let module Gen = Dopri5.Integrator (CassdSys) (Algp) in
  Gen.simulate !chan_r !tf_r y0

let () = ignore (main ())
