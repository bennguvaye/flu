(* system parameter values *)
let n_r = ref (10. ** 6.);;
let rr0_r = ref (2.);;
let e_r = ref (0.15);;
let etaN_r = ref (10. ** (-7.1));;
let g_r = ref (1. /. (14. *. 365.));;
let nu_r = ref (1. /. 2.77);;

(* simulation arguments *)
let tf_r = ref (365. *. 200.);;
(* FIXME need to recompute y0 later (if size_r has been changed) *)
let s0_r = ref (int_of_float (0.5 *. !n_r));;
let i0_r = ref (int_of_float (0.001 *. !n_r));;
let r0_r = ref (int_of_float (0.499 *. !n_r));;

(* Algorithm parameters *)
let step_size_r = ref 0.25;;

let main () =
  let change_chan_to_file co_r s =
    co_r := open_out s
  in
  let chan_r = ref stdout in
  let specy0 =
        [Arg.Int (fun x -> s0_r := x);
         Arg.Int (fun x -> i0_r := x);
         Arg.Int (fun x -> r0_r := x);] in
  let specl = 
        [("-dest", Arg.String (change_chan_to_file chan_r),
                ": location of the destination CSV file");
         ("-tf", Arg.Set_float tf_r,
                ": Simulate until (in days)");
         ("-y0", Arg.Tuple specy0,
                ": Initial conditions (Should sum to 1)");
         ("-N", Arg.Set_float n_r, 
                ": Total number of hosts in the population");
         ("-R0", Arg.Set_float rr0_r, 
                ": Basic reproductive ratio");
         ("-e", Arg.Set_float e_r, 
                ": Strength of the seasonal forcing");
         ("-etaN", Arg.Set_float etaN_r, 
                ": Intensity of immigration (per host)");
         ("-g", Arg.Set_float g_r, 
                ": Frequency of immunity loss (1/days)");
         ("-nu", Arg.Set_float nu_r, 
                ": Frequency of recovery from infection (1/days)");
         ("-step_size", Arg.Set_float step_size_r,
                ": Minimum resolution in time. Must be > 0.")]
  in
  (* simply ignore anonymous arguments *)
  let anon_print s = print_endline ("Ignored anonymous argument : " ^ s) in
  (* printed before the help message : *)
  let usage_msg = "  Simulate using Euler_multinomial(.ml) a single strain " ^
                  "seasonally forced SIR model approximating (for example) " ^
                  "influenza dynamics." ^
                  "\nFor more info, look into sss.mli and gill.mli" in
  (* parse the command line and update the parameter values *)
  Arg.parse specl anon_print usage_msg ;
  (* sanity check *)
  let init_sz = !s0_r + !i0_r + !r0_r in
  if not (init_sz = int_of_float !n_r) then
    failwith ("The announced population size is not equal to the initial population size : \n" 
              ^ (string_of_float !n_r) ^ " != " ^ (string_of_int init_sz));
  let module Pars = 
    struct
      let n = !n_r
      let r0 = !rr0_r
      let e = !e_r
      let etaN = !etaN_r
      let g = !g_r
      let nu = !nu_r
    end
  in
  let module SssSys = Sss.Sys (Pars) in
  let module Algp =
    struct
      let step_size = !step_size_r
    end
  in
  let module Gen = Euler_multinomial.Integrator (SssSys) (Algp) in
  ignore(Gen.simulate !chan_r !tf_r (!s0_r, !i0_r, !r0_r))

let () = main ()
