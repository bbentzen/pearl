(**
  (c) Copyright 2019 Bruno Bentzen. All rights reserved.
  Released under Apache 2.0 license as described in the file LICENSE.

  Desc: This module contains error messages displayed by the type checker and elaborator.
        Error messages are grouped by type, except that unification messages are kept apart.
 **)

open Basis
open Context

(* Locals *)

let unexpected index ty ctx =
  "Unexpected local variable when checking that the term " ^
  Pretty.printf (Local index) ^
  " has type " ^ Pretty.printf ty ^
  "\n" ^ Global.printf ctx

(* Globals *)

let goal_msg ctx e ty =
  "when checking that\n  " ^ Pretty.printf e ^ "\nhas the expected type\n" ^ Global.printf ctx ^ 
  "-------------------------------------------\n ⊢ " ^ Pretty.printf ty

let undeclared x =
  "No declaration for the variable " ^ x

let var_type_mismatch x xty ty msg = 
  "The variable " ^ x ^ " has type\n   " ^ Pretty.printf xty ^ 
  "\nbut is expected to have type\n  " ^ Pretty.printf ty ^ "\n" ^ msg

let var_error x msg = 
  "Error at type checking the variable " ^ x ^ ": " ^ msg

let var_error_2 x = 
  "Error at type checking the variable " ^ x ^ ": "

let var_type_mismatch_2 x xty ty = 
  "The variable " ^ x ^ " has type\n   " ^ Pretty.printf xty ^ 
  "\nbut is expected to have type\n  " ^ Pretty.printf ty ^ "\n"

(* Function type checking error messages *)

let lam_error x e ty =
  "The term\n  " ^ Pretty.printf (Lam (x, e)) ^ 
  "\nhas type\n  " ^ Pretty.printf ty ^ "\nbut is expected to have type\n  Π (v? : ?0?) ?1?"

let app_fail_1 e2' ty1' msg = 
  "Failed application: the term in the argument position \n  " ^ Pretty.printf e2' ^ 
  "\nis expected to have type\n  " ^ Pretty.printf ty1' ^ "\n" ^ msg

let app_fail_2 e2 ty1' msg = 
  "Failed application: the term in the argument\n  " ^ Pretty.printf e2 ^ 
  "\nis expected to have type\n  " ^ Pretty.printf ty1' ^ "\n" ^ msg

let app_wrong_ty1 e1' h2 ty1' =
  "Failed application: the term in function position\n  " ^ Pretty.printf e1' ^ 
  "\nis expected to have the type\n " ^ Pretty.printf h2 ^
  "\nbut was found to have type\n " ^ Pretty.printf ty1'

let app_wrong_ty2 e1 msg =
  "Failed application: the term in function position\n  " ^ Pretty.printf e1 ^ 
  "\nis expected to have a function type.\n " ^ msg

let pi_universe_1 x ty1 ty2 max m =
  "Universe level mismatch when checking that the type\n  " ^ Pretty.printf (Pi(x, ty1, ty2)) ^
  "\nof type \n  " ^ Pretty.printf (Type max) ^ "\nhas type\n  " ^ Pretty.printf (Type m)

let pi_universe_2 x ty1 ty2 ty =
  "Type mismatch when checking that\n  " ^ Pretty.printf (Pi(x, ty1, ty2)) ^ "\nhas type\n  " ^ Pretty.printf ty

let pi_codomain ty2' msg =
  "Failed to check that the codomain\n  " ^ Pretty.printf (Eval.eval ty2') ^ "\nis a type\n" ^ msg

let pi_domain ty1 msg =
  "Failed to check that the domain\n  " ^ Pretty.printf (Eval.eval ty1) ^ "\nis a type\n" ^ msg

let pi_unexpected x ty1 ty2 ty ty1' u1 ty2' u2 =
  "Failed to show that the dependent function " ^ Pretty.printf (Pi(x, ty1, ty2)) ^ " has the expected type " ^ Pretty.printf ty ^ ". Can only check that\n  " ^ 
  Pretty.printf ty1' ^ "\nhas type " ^ Pretty.printf u1 ^
  "\nand that\n  " ^ Pretty.printf ty2' ^ "\nhas type " ^ Pretty.printf u2

let not_a_pi_type ty1' =
  "Type mismatch when checking that\n  " ^ Pretty.printf ty1' ^ "\nhas type\n  Π (v? : I) ?0?. "

(* Void *)

let void_error e msg =
  "Type mismatch when checking that " ^ Pretty.printf e ^ 
  "has type " ^ Pretty.printf (Void()) ^ ". " ^ msg

let void_ty ty =
"Type mismatch when checking that\n  void\n has type\n  " ^ Pretty.printf ty

(* Equality *)

(* Types and universes *)

let not_a_type ty =
  "Failed to check that\n  " ^ Pretty.printf ty ^ "\nis a type."

let not_a_type_2 ty msg =
  "Failed to check that\n  " ^ Pretty.printf ty ^ "\nis a type.\n" ^ msg

let type_unexpected e1 =
  "Failed to check that\n  " ^ Pretty.printf e1 ^ "\nhas type\n ?0?."

let type_unexpected_2 e1 msg =
  "Failed to check that\n  " ^ Pretty.printf e1 ^ "\nhas type\n ?0?.\n" ^ msg

let type_unexpected_3 e1 n msg =
"Failed to check that\n  " ^ Pretty.printf e1 ^ "\nhas type\n " ^ Pretty.printf (Meta n) ^ "\n" ^ msg

let universe_inconsitency n m =
  "Universe inconsistency: the universe level of\n  " ^ Pretty.printf (Type n) ^ 
  "\nmust be inferior to the universe level of\n  " ^ Pretty.printf (Type m) ^ 
  "\nFailed to prove that " ^ Pretty.print_level n ^ " ≤ " ^ Pretty.print_level m ^ "."

let type_mismatch n ty =
  "Type mismatch when checking that\n  " ^ Pretty.printf (Type n) ^ 
  "\nhas type\n  " ^ Pretty.printf ty

(* Wildcard *)

let synthesis_error ty n ctx =
  "Failed to synthesize placeholder for ?" ^ string_of_int n ^ "? in the current goal:\n" ^ 
  Global.printf ctx ^ "-------------------------------------------\n ⊢ " ^ Pretty.printf (Eval.eval ty)

let display_goal ctx ty =
  "The current goal:\n" ^ Global.printf ctx ^ 
  "-------------------------------------------\n ⊢ " ^ 
  Pretty.printf ty

(* Unification error messages for all expressions *)

let unify_pi msg =
  "Unification failed at function type: " ^ msg

let unify_eq e e1 e2 e' e1' e2' msg =
  "Don't know how to unify the equality types \n  " ^ Pretty.printf (Eq (e, e1, e2)) ^ 
  "\nand\n  " ^ Pretty.printf (Eq (e', e1', e2')) ^ " due to the following errors:\n " ^ msg

let app_unify_fallback e1 e2 e1' e2' msg =
  "Failed to unify the applications " ^ Pretty.printf (App (e1, e2)) ^ 
              " and " ^ Pretty.printf (App (e1', e2')) ^ ". " ^ msg

let app_unify_arg e2 h1 msg =
  "Failed to check that " ^ Pretty.printf e2 ^ " has type " ^ Pretty.printf h1 ^ ".\n" ^ msg

let app_unify_app e i e' =
  "Don't know how to unify the applied term\n  " ^ Pretty.printf (App (e, i)) ^ "\nwith\n  " ^ Pretty.printf e' ^ "." 

let generic_unify e0 e0' msg =
  "Don't know how to unify\n  " ^ Pretty.printf e0 ^ "\nwith\n  " ^ Pretty.printf e0' ^ ".\n" ^ msg

let generic_unify_2 e0 e0' =
  "Don't know how to unify\n  " ^ Pretty.printf e0 ^ "\nwith\n  " ^ Pretty.printf e0' ^ "." 

let universe_unify m n =
  "Could not unify after lifting the universe levels of the types\n  " ^ 
  Pretty.printf (Type m) ^ "\nand\n  " ^ Pretty.printf (Type n)

let universe_unify_2 m n =
  "The types\n  " ^ Pretty.printf (Type m) ^ "\nand\n  " ^ 
  Pretty.printf (Type n) ^ "\nhave incompatible universe levels"

let lam_unify x e e' =
  let e = Expr.open_var 0 (Global x) e in
  "Don't know how to unify the lambda abstraction\n  " ^ 
  Pretty.printf (Lam (x, e)) ^ "\nwith the term\n  " ^ Pretty.printf e'

let not_syntactically_equal e e' =
  "The two terms\n  " ^ Pretty.printf e ^ "\nand\n  " ^ Pretty.printf e' ^ "\nare not equal. "

(* Equality *)

let eq_universe_1 ty1 e1 e2 max m =
  "Universe level mismatch when checking that the type\n  " ^ Pretty.printf (Eq(ty1, e1, e2)) ^
  "\nof type \n  " ^ Pretty.printf (Type max) ^ "\nhas type\n  " ^ Pretty.printf (Type m)

let eq_universe_2 ty1 e1 e2 ty =
  "Type mismatch when checking that\n  " ^ Pretty.printf (Eq(ty1, e1, e2)) ^ "\nhas type\n  " ^ Pretty.printf ty

let rfl_error_1 ty msg =
  "Failed reflexivity: could not unify both sides of \n  " ^ Pretty.printf ty ^ ".\n" ^ msg

let rfl_error_2 ty =
  "rfl has type\n  " ^ Pretty.printf ty ^ "\nbut is expected to have type\n  ?1? =?0? ?2?"

let reflect_1 e1 ty1 =
  "Cannot resolve reflection: The term\n  " ^ Pretty.printf e1 ^ 
  "\nhas type\n  " ^ Pretty.printf ty1 ^ "\nbut is expected to have type\n  ?1? =?0? ?2?"

let reflect_2 e msg =
  "Failed to resolve reflection: Cannot check that the term\n  " ^ Pretty.printf e ^ 
  "\nhas type\n  ?1? =?0? ?2?" ^ msg

  let reflect_goal ctx e2 ty msg =
  "Failed reflection " ^ goal_msg ctx e2 ty ^ "\n" ^ msg
