(**
  (c) Copyright 2026 Bruno Bentzen. All rights reserved.
  Released under Apache 2.0 license as described in the file LICENSE.
  
  Desc: Handles unification constraints. 
 **)

open Basis.Ast

type constraint_ = {
  lhs   : expr;
  rhs   : expr;
  cty   : expr;   (* type at which we compare *)
  clift : bool;   (* universe-lifting flag *)
}

type state = {
  mutable subst       : (int, expr) Hashtbl.t;
  mutable constraints : constraint_ list;
}

let empty () = { subst = Hashtbl.create 64; constraints = [] }

let add st c = st.constraints <- c :: st.constraints

let assign st n e = Hashtbl.replace st.subst n e

let lookup st n = Hashtbl.find_opt st.subst n

(* Apply the current substitution to an expression, recursively. *)

let rec zonk st = function
  | Meta n ->
    begin match lookup st n with
    | Some e -> zonk st e
    | None -> Meta n
    end
  | Lam (x, e) -> Lam (x, zonk st e)
  | App (e1, e2) -> App (zonk st e1, zonk st e2)
  | Pi (x, e1, e2) -> Pi (x, zonk st e1, zonk st e2)
  | Eq (e, e1, e2) -> Eq (zonk st e, zonk st e1, zonk st e2)
  | Reflect (e1, e2) -> Reflect (zonk st e1, zonk st e2)
  | Explode (e1, e2) -> Explode (zonk st e1, zonk st e2)
  | Local _ | Global _ | Void _ | Rfl _ | Type _ | Wild _ as e -> e