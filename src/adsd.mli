(** Double strain age-structured deterministic simulation module *)

(** Module for parameter values *)
module type PARS =
  sig
    (** Number of age-classes *)
    val a : int
    (** Number of hosts *)
    val size : float
    (** Basic reproductive ratio *)
    val r0 : float
    (** Strength of the seasonal forcing *)
    val e : float
    (** Immigration rate (per host) of the first strain *)
    val etaN1 : float
    (** Immigration rate (per host) of the second strain *)
    val etaN2 : float
    (** Immunity loss rate of the first strain *)
    val g1 : float
    (** Immunity loss rate of the second strain *)
    val g2 : float
    (** Recovery rate *)
    val nu : float
    (** Full cross-immunity loss rate *)
    val q : float
    (** Relative sensibilities of age-classes *)
    val sensi_v : Lacaml_float64.vec
    (** Proportions of the age-classes in the population *)
    val prop_v : Lacaml_float64.vec
    (** Contact matrix *)
    val cont_m : Lacaml_float64.mat
    val init_perturb : float
    val dilat_bound : float
  end;;

(** Functor initializing the module associated to parameter values *)
module Sys : functor (Pars : PARS) -> Dopri5.SYSTEM

(** Reasonable algorithm parameter values *)
module Default_Algp : Dopri5.ALGPARAMS


