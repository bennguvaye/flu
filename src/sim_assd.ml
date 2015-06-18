open Lacaml.D

(* system parameter values *)
let size_r = ref (10. ** 5.)
let r0_r = ref (2.)
let e_r = ref (0.15)
let etaN_r = ref (10. ** (-7.1))
let g_r = ref (1. /. (14. *. 365.))
let nu_r = ref (1. /. 2.77)
(* variational system behaviour *)
let init_perturb_r = ref (10. ** (~-. 8.))
let dilat_bound_r = ref 10.

(* simulation arguments *)
let tf_r = ref (365. *. 200.)

(* FIXME initialize all that later in file ? *)
(* FIXME find the right values *)
(* FIXME problem if the user changes one but not the other *)
let m_r = ref 3
let prop_r = ref (Vec.of_array
              [| 0.3 ; 0.4 ; 0.3 |])

let sensi_r = ref (Vec.of_array
              [| 1.5 ; 1. ; 2. |])
let cont_r = ref (Mat.of_array
              [| 
                [| 0. ; 0. ; 0. |] ;
                [| 0. ; 0. ; 0. |] ; 
                [| 0. ; 0. ; 0. |] 
              |])

let f = fun n -> Random.float 2. -. 1. 
let rd_a = Vec.init (!m_r * 3) f
let s = Vec.fold (+.) 0. rd_a
let dx_0 = Vec.map (fun x -> (x -. s) *. !init_perturb_r) rd_a

let psir_0 = [ 0.5 ; 0.001 ; 0.499 ]
let x_0 = Vec.concat 
  (List.map 
      (fun x -> Vec.map (fun y -> x *. y *. !size_r) !prop_r) 
   psir_0)

let y0 = Vec.append x_0 dx_0

(* Algorithm parameters *)
let h0_r = ref (1. /. (24. *. 60.))
let delta_r = ref 0.1
let min_step_r = ref (1. /. (24. *. 3600.))
let max_step_r = ref 1.

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
  let data = Csv.load fname in
  match data with
  | [] -> 
      failwith "no data read from file"
  | l1 :: [] -> 
      failwith "file has only one line"
  | l1 :: _ ->
      let ll = List.map 
          (fun l -> List.map (fun s -> float_of_string s) l) data in
      let m = Mat.of_array 
          (Array.of_list (List.map (fun l -> Array.of_list l) ll))
      in m_r := m

let main () =
  let chan_r = ref stdout in
  let specy0 = 
        [Arg.Float (fun x -> y0.{1} <- x);
         Arg.Float (fun x -> y0.{2} <- x);
         Arg.Float (fun x -> y0.{3} <- x);] in
  let specl = 
        [("-dest", Arg.String (change_chan_to_file chan_r),
                ": location of the destination CSV file.\n" ^ 
                "      If not given, outputs to standard output.");
         ("-tf", Arg.Set_float tf_r,
                ": Simulate until (in days)");
         ("-y0", Arg.Tuple specy0,
                ": Initial conditions (Should sum to N)");
         ("-N", Arg.Set_float size_r, 
                ": Total number of hosts in the population");
         ("-R0", Arg.Set_float r0_r, 
                ": Basic reproductive ratio");
         ("-e", Arg.Set_float e_r, 
                ": Strength of the seasonal forcing");
         ("-etaN", Arg.Set_float etaN_r, 
                ": Intensity of immigration (per host)");
         ("-g", Arg.Set_float g_r, 
                ": Frequency of immunity loss (1/days)");
         ("-nu", Arg.Set_float nu_r, 
                ": Frequency of recovery from infection (1/days)");
         ("-m", Arg.Set_int m_r,
                ": Number of age classes (default 3)");
         ("-fprop", Arg.String (load_vec_from_file prop_r),
                " : File location of the proportions of each age class");
         ("-fsensi", Arg.String (load_vec_from_file sensi_r),
                ": File location of the sensibilities for each age class");
         ("-fcont", Arg.String (load_mat_from_file cont_r),
                ": File location of the contact matrix between age classes");
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
  (* sanity check *)
  let init_sz = y0.{1} +. y0.{2} +. y0.{3} in
  if not (init_sz = !size_r) then
    failwith ("The announced population size is not equal to the initial population size : \n" 
              ^ (string_of_float !size_r) ^ " != " ^ (string_of_float init_sz));
  let module Pars = 
    struct
      let size = !size_r
      let r0 = !r0_r
      let e = !e_r
      let etaN = !etaN_r
      let g = !g_r
      let nu = !nu_r
      let sensi_v = !sensi_r
      let prop_v = !prop_r
      let cont_m = !cont_r
      let init_perturb = !init_perturb_r
      let dilat_bound = !dilat_bound_r
    end
  in
  let module AssdSys = Assd.Sys (Pars) in
  let module Algp =
    struct
      let h0 = !h0_r
      let delta = !delta_r
      let min_step = !min_step_r
      let max_step = !max_step_r
    end
  in
  let module Gen = Dopri5.Integrator (AssdSys) (Algp) in
  Gen.simulate !chan_r !tf_r y0

let () = ignore (main ())