(**
  (c) Copyright 2026 Bruno Bentzen. All rights reserved.
  Released under Apache 2.0 license as described in the file LICENSE.

  Desc: This file contains basic operations on expressions, including shifting, opening, closing, and substituting variables. 
        Local variables are objects of the form "Local <index>" of type expr, which 
        are identified as indices in pure de Bruijn form.
**)

open Ast

let rec shift cutoff amount = function
  | Local index ->
    if index >= cutoff then Local (index + amount)
    else Local index
  | Global _ | Void _ | Type _ | Wild _ | Meta _ as e -> e
  | Lam (x, e) -> Lam (x, shift (cutoff + 1) amount e)
  | App (e1, e2) -> App (shift cutoff amount e1, shift cutoff amount e2)
  | Pi (x, e1, e2) -> Pi (x, shift cutoff amount e1, shift (cutoff + 1) amount e2)
  | Rfl () -> Rfl ()
  | Eq (e, e1, e2) -> Eq (shift cutoff amount e, shift cutoff amount e1, shift cutoff amount e2)
  | Reflect (e1, e2) -> Reflect (shift cutoff amount e1, shift cutoff amount e2)
  | Explode (e1, e2) -> Explode (shift cutoff amount e1, shift cutoff amount e2)
  | ESubIn (e, e1, e2) -> ESubIn (shift cutoff amount e, shift cutoff amount e1, shift cutoff amount e2)

  (* Additional functions *)

let rec open_var k replace = function
  | Local index ->
    if index = k then shift 0 k replace
    else if index > k then Local (index - 1)
    else Local index
  | Global _  | Void _ | Rfl _ | Type _ | Wild _ | Meta _ as e -> e
  | Lam (x, e) -> Lam (x, open_var (k + 1) replace e)
  | App (e1, e2) -> App (open_var k replace e1, open_var k replace e2)
  | Pi (x, e1, e2) -> Pi (x, open_var k replace e1, open_var (k + 1) replace e2)
  | Eq (e, e1, e2) -> Eq (open_var k replace e, open_var k replace e1, open_var k replace e2)
  | Reflect (e1, e2) -> Reflect (open_var k replace e1, open_var k replace e2)
  | Explode (e1, e2) -> Explode (open_var k replace e1, open_var k replace e2)
  | ESubIn (e, e1, e2) -> ESubIn (open_var k replace e, open_var k replace e1, open_var k replace e2)

let rec close_var k x = function
  | Global y when x = y -> Local k
  | Global _ | Local _ | Void _ | Rfl _ | Type _ | Meta _ | Wild _ as e -> e
  | Lam (y, e) -> Lam (y, close_var (k + 1) x e)
  | App (e1, e2) -> App (close_var k x e1, close_var k x e2)
  | Pi (y, e1, e2) -> Pi (y, close_var k x e1, close_var (k + 1) x e2)
  | Eq (e, e1, e2) -> Eq (close_var k x e, close_var k x e1, close_var k x e2)
  | Reflect (e1, e2) -> Reflect (close_var k x e1, close_var k x e2)
  | Explode (e1, e2) -> Explode (close_var k x e1, close_var k x e2)
  | ESubIn (e, e1, e2) -> ESubIn (close_var k x e, close_var k x e1, close_var k x e2)

(* Abbreviations for opening and closing binders *)

let open_bound replace body =
  open_var 0 replace body

let close_bound binder body =
  close_var 0 binder body

(* Legacy substitution function: replaces ex with d in argument *)

let rec fullsubst k ex d = function
  | e when e = (shift 0 k ex) -> shift 0 k d
  | Global _ | Local _ | Void _ | Rfl _ | Type _ | Wild _ as e -> e
  | Lam (y, e) -> Lam (y, fullsubst (k+1) ex d e)
  | App (e1, e2) -> App (fullsubst k ex d e1, fullsubst k ex d e2)
  | Pi (y, e1, e2) -> Pi (y, fullsubst k ex d e1, fullsubst (k+1) ex d e2)
  | Eq (e, e1, e2) -> Eq (fullsubst k ex d e, fullsubst k ex d e1, fullsubst k ex d e2)
  | Meta n -> Meta n
  | Reflect (e1, e2) -> Reflect (fullsubst k ex d e1, fullsubst k ex d e2)
  | Explode (e1, e2) -> Explode (fullsubst k ex d e1, fullsubst k ex d e2)
  | ESubIn (e, e1, e2) -> ESubIn (fullsubst k ex d e, fullsubst k ex d e1, fullsubst k ex d e2)

(* Syntactical substitution ignoring bound occurrences - useful for reflection *)
(* This must be used very carefully *)

let rec reflsubst k ex d = function
  | e when e = ex -> d
  | Global _ | Local _ | Void _ | Rfl _ | Type _ | Wild _ as e -> e
  | Lam (y, e) -> Lam (y, reflsubst (k+1) ex d e)
  | App (e1, e2) -> App (reflsubst k ex d e1, reflsubst k ex d e2)
  | Pi (y, e1, e2) -> Pi (y, reflsubst k ex d e1, reflsubst (k+1) ex d e2)
  | Eq (e, e1, e2) -> Eq (reflsubst k ex d e, reflsubst k ex d e1, reflsubst k ex d e2)
  | Meta n -> Meta n
  | Reflect (e1, e2) -> Reflect (reflsubst k ex d e1, reflsubst k ex d e2)
  | Explode (e1, e2) -> Explode (reflsubst k ex d e1, reflsubst k ex d e2)
  | ESubIn (e, e1, e2) -> ESubIn (reflsubst k ex d e, reflsubst k ex d e1, reflsubst k ex d e2)

(* Occurrence of indices: note that the first arguments of reflect and explode are ignored *)
(* This is useful to allow for eta-conversion *)

let rec occurs_index target cutoff = function
  | Local index -> index = target + cutoff
  | Global _ | Void _ | Rfl _ | Type _ | Wild _ | Meta _ -> false
  | Lam (_, e)  -> occurs_index target (cutoff + 1) e
  | App (e1, e2) -> occurs_index target cutoff e1 || occurs_index target cutoff e2
  | Pi (_, e1, e2) -> occurs_index target cutoff e1 || occurs_index target (cutoff + 1) e2
  | Eq (e, e1, e2) -> occurs_index target cutoff e || occurs_index target cutoff e1 || occurs_index target cutoff e2
  | Reflect (_, e) | Explode (_, e) | ESubIn (e, _, _) -> occurs_index target cutoff e

let rec occurs_name s hint = function
  | Lam (x, e) -> x = hint || occurs_name x hint e
  | Pi (x, e1, e2) -> x = hint || occurs_name x hint e1 || occurs_name x hint e2
  | Local _ -> s = hint | Global t -> t = hint
  | Void _ | Rfl _ | Type _ | Wild _ | Meta _ -> false
  | App (e1, e2) | Reflect (e1, e2) | Explode (e1, e2) -> occurs_name s hint e1 || occurs_name s hint e2
  | Eq (e, e1, e2) | ESubIn (e, e1, e2) -> occurs_name s hint e || occurs_name s hint e1 || occurs_name s hint e2

let rec free_occurs_name s = function
  | Global t -> t = s  
  | Local _ | Void _ | Rfl _ | Type _ | Wild _ | Meta _ -> false
  | Lam (x, e) -> free_occurs_name x e
  | Pi (x, e1, e2) -> free_occurs_name x e1 || free_occurs_name x e2
  | App (e1, e2) | Reflect (e1, e2) | Explode (e1, e2) -> free_occurs_name s e1 || free_occurs_name s e2
  | Eq (e, e1, e2) | ESubIn (e, e1, e2) -> free_occurs_name s e || free_occurs_name s e1 || free_occurs_name s e2

(* Converts a list of expressions into a single expression by application *)

let rec list_to_expr l =
  match l with
  | [] -> Void() (* This is arbitrary *)
  | e :: es -> App (e, list_to_expr es)

(* Creates n-many fresh variables from a list es of expressions *)

let create_fresh_char c es n =
  let rec helper i e n =
    if occurs_name (c ^ "0") (c ^ string_of_int i) e then
      helper (i+1) e n
    else if n > 0 then
      Array.append [| c ^ string_of_int i |] (helper (i+1) e (n-1))
    else
      [| |]
  in  (* not free_var *)
  helper 0 (list_to_expr es) n

let create_fresh es n = create_fresh_char "v" es n

let init_fresh n = "v" ^ string_of_int n

(* Returns the first fresh variable v, v1, v2, ... not occurring in the context *)

let mk_fresh var ctx =
  let used = Hashtbl.create (List.length ctx * 2) in
  List.iter (fun (y, _, _) -> Hashtbl.replace used y ()) ctx;
  let rec loop i =
    let cand = if i = 0 then var else var ^ string_of_int i in
    if Hashtbl.mem used cand then loop (i + 1) else cand
  in
  loop 0

(* Extract realizer of a proof: removes reflect, explode, revert explicit substitutions *)
(* Importantly, this also generalizes universe levels --- to save computational power we do this all in one go*)

let parametrize = function
    | Var par -> 
      if String.length par > 0 && par.[0] = '?' then Var par else
      Var ("?" ^ par)
    | l -> l

let rec realizer_of = function
  | Lam (y, e) -> Lam (y, realizer_of e)
  | App (e1, e2) -> App (realizer_of e1, realizer_of e2)
  | Pi (y, e1, e2) -> Pi (y, realizer_of e1, realizer_of e2)
  | Eq (e, e1, e2) -> Eq (realizer_of e, realizer_of e1, realizer_of e2)
  | Meta n -> Meta n
  | Reflect (_, e) | Explode (_, e) -> realizer_of e
  | ESubIn (_, e, _) -> realizer_of e
  | Type l -> Type (parametrize l)
  | Global _ | Local _ | Void _ | Rfl _ | Wild _ as e -> e

(* Weak head realizer extraction useful for pattern matching at elaboration *)

let rec type_of = function
  | App (e1, e2) -> App (type_of e1, type_of e2)
  | Reflect (_, e) | Explode (_, e) -> type_of e
  | ESubIn (_, e, _) -> type_of e
  | e -> e