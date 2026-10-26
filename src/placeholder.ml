(**
  (c) Copyright 2019 Bruno Bentzen. All rights reserved.
  Released under Apache 2.0 license as described in the file LICENSE.
 
  Desc: This file contains basic operations involving placeholders (metavariables). This
        includes generating placeholders, checking whether an expression is a placeholder,
        and checking whether an expression has placeholders. The bool argument for metas is
        used to track when they allow for motive/index inference (true). 
 **)

open Ast

(* Generates a placeholder *)

let counter = ref 0

let generate () =
  incr counter; Meta (!counter, true)

let restore n = 
  counter := n;
  Hashtbl.clear Data.meta_store

(* Implicit counter *)

let implicit_counter = ref 0

let impl_generate () =
  incr implicit_counter;
  Meta (!implicit_counter, true)

(* Determines whether an expression is a placeholder/underscore with a variant up to eta *)

let is = function
  | Meta _ | Wild _ -> true
  | _ -> false

  (* Determines whether an expression is an underscore *)

let is_wild = function
  | Wild _ -> true 
  | _ -> false

let is_meta = function
  | Meta _ -> true 
  | _ -> false

let can_be_inferred = function
  | Meta (_, b) -> b 
  | Wild _ -> true
  | _ -> false

let inferred_with_eta = function
  | Lam (_, App(e, Local 0)) when can_be_inferred e -> true
  | e -> can_be_inferred e

let flag_meta_use = function
  | Meta (n, _) -> Meta (n, false) 
  | e -> e

(* Tail-recursive recursion with stack for placeholder tracking  *)

let has_placeholder term =
  let rec helper stack =
    match stack with
    | [] -> false
    | x :: rest ->
      match x with
      | Meta _ -> true
      | Pi (_, e1, e2) | App (e1, e2) | Quot (e1, e2) | Mkq (e1, e2) | Reflect (e1, e2) -> helper (e1 :: e2 :: rest)
      | Lam (_, e) -> helper (e :: rest)
      | Eq (e, e1, e2) -> helper (e :: e1 :: e2 :: rest)
      | _ -> helper rest
  in
  helper [term]

let has_placeholder_name name term =
  let rec helper stack =
    match stack with
    | [] -> false
    | x :: rest ->
      match x with
      | Meta (n, _) when n = name -> true
      | Meta _ -> false
      | Pi (_, e1, e2) | App (e1, e2) | Quot (e1, e2) | Mkq (e1, e2) | Reflect (e1, e2) -> helper (e1 :: e2 :: rest)
      | Lam (_, e) -> helper (e :: rest)
      | Eq (e, e1, e2) -> helper (e :: e1 :: e2 :: rest)
      | _ -> helper rest
  in
  helper [term]

(* Determines whether an expression has placeholders or underscores *)

let has term =
  let rec helper stack =
    match stack with
    | [] -> false
    | x :: rest ->
      match x with
      | Wild _ | Meta _ -> true
      | Lam (_, e) -> helper (e :: rest)
      | Pi (_, e1, e2) | App (e1, e2) | Quot (e1, e2) | Mkq (e1, e2) -> helper (e1 :: e2 :: rest)
      | Eq (e, e1, e2) -> helper (e :: e1 :: e2 :: rest)
      | Reflect (_, e) -> helper (e :: rest)
      | _ -> helper rest
  in
  helper [term]

(* Zonks an expression with the solved metavariables *)

let rec solve env = function
  | Meta (n, b) -> 
    begin match Hashtbl.find_opt Data.meta_store n with
    | Some stored ->
      (* Close any open variables the solved meta might contain *)
      let rec bind count e = function
        | [] -> e
        | x :: env -> bind (count + 1) (Expr.close_var count x e) env 
      in
      bind 0 stored.solution env
    | None -> Meta (n, b)
    end
  | Pi (x, e1, e2) -> Pi (x, Eval.eval (solve env e1), Eval.eval (solve (x :: env) e2))
  | Lam (x, e) -> Lam (x, Eval.eval (solve (x :: env) e))
  | App (e1, e2) -> App (solve env e1, solve env e2)  
  | Eq (e, e1, e2) -> Eq (solve env e, solve env e1, solve env e2)
  | Quot (e1, e2) -> Quot (solve env e1, solve env e2)
  | Mkq (e1, e2) -> Mkq (solve env e1, solve env e2)
  | Reflect (e1, e2) -> Reflect (solve env e1, solve env e2)
  | ESubIn (e, e1, e2) -> ESubIn (solve env e, solve env e1, solve env e2)
  | Local _ | Global _ | Void _ | Rfl _ | Type _ | Wild _ as e -> e
  
(* Assigns unique positive metas to negative metas *)

let rec unique = function
  | Local _ | Global _ | Void _ | Rfl _ | Type _ | Wild _ as e -> e
  | Meta _ -> generate ()
  | Pi (x, e1, e2) -> Pi (x, unique e1, unique e2)
  | Lam (x, e) -> Lam (x, unique e)
  | App (e1, e2) -> App (unique e1, unique e2)
  | Eq (e, e1, e2) -> Eq (unique e, unique e1, unique e2)
  | Quot (e1, e2) -> Quot (unique e1, unique e2)
  | Mkq (e1, e2) -> Mkq (unique e1, unique e2)
  | Reflect (e1, e2) -> Reflect (unique e1, unique e2)
  | ESubIn (e, e1, e2) -> ESubIn (unique e, unique e1, unique e2)

(* Takes two expressions and returns the first if the second is a meta variable *)
let without e1 = function
  | Meta _ -> e1
  | e2 -> e2

let rec close var = function
  | Meta (n, _) -> 
    begin match Hashtbl.find_opt Data.meta_store n with
    | Some stored ->
      (* Close any globals variables the solved meta might contain *)
      begin Hashtbl.replace Data.meta_store n {solution =
      Expr.close_bound var stored.solution}
      end
    | None -> ()
    end
  | Lam (_, e) -> close var e
  | Pi (_, e1, e2) | App (e1, e2) | Quot (e1, e2) | Mkq (e1, e2) | Reflect (e1, e2) -> close var e1; close var e2
  | Eq (e, e1, e2) | ESubIn (e, e1, e2) -> close var e; close var e1; close var e2
  | Local _ | Global _ | Void _ | Rfl _ | Type _ | Wild _ -> ()