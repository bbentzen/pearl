(**
  (c) Copyright 2019 Bruno Bentzen. All rights reserved.
  Released under Apache 2.0 license as described in the file LICENSE.
  
  Desc: Typechecked definitions are appended to an "environment", a list of
        identifiers with their proof term and their type. Identifiers are used as 
        global variables in the internal de Bruijn representation of terms.
        This file handles operations on this environment list.
 **)

open Basis
open Ast
open Expr

let rec var_type x env =
  match env with
  | [] -> Error()
  | ((y, (_, ty)), _) :: env' -> 
    if x = y then Ok ty else var_type x env'

(* Determines whether a string is declared in the environment *)

let is_declared x env =
  let rec helper x = function
    | [] -> false
    | ((id,_), _) :: env -> 
      if x = id then 
        true
      else 
        helper x env
  in
  helper x (List.rev env)

(* Generates a triple id * term * type from a successfully elaborated triple id * ctx * elab *)

let function_of_def id ctx (e, ty) hole =
  let rec helper h' = function
    | [] -> e, ty
    | (x, ty, true) :: ctx ->
      let e', ty' = helper h' ctx in
      Lam (x, close_var 0 x e'), 
      Pi (x, ty, close_var 0 x ty')
    | (x, _, false) :: ctx ->
      let e', ty' = helper (h'+1) ctx in
      let h = Placeholder.generate_neg () in
      Global.subst_global 0 h x e', 
      Global.subst_global 0 h x ty' 
  in
  id, helper hole ctx

let rec check_def_id id = function
  | [] -> 
    Error ("No definition or theorem found for the identifier '" ^ id ^ "'") 
  | ((id', body), _) :: env -> 
    if id = id'
    then Ok body
    else check_def_id id env

(* Appends a quadruple (id * (term * type)) * attrb to the env context *)

let add env id ctx elab attrb =
  match check_def_id id env with
  | Ok _ -> env
  | Error _ -> 
    Placeholder.restore 0;
    (function_of_def id ctx elab 0, attrb) :: env

(* Returns the body of a definition when given a declared env constant *)

let rec unfold id = function
  | [] -> 
    Error ("No declaration found for identifier '" ^ id ^ "'")
  | ((id', (body , ty)), attrb) :: env -> 
    if id = id' then 
      Ok ((body, ty), attrb)
    else 
      unfold id env

(* Uniformly lifts all indices of implicit arguments in a env variable *)

let rec lift n = function
  | Wild m -> Wild (m+n)
  | Lam (y, e) -> Lam (y, lift n e)
  | App (e1, e2) -> App (lift n e1, lift n e2)
  | Pi (y, e1, e2) -> Pi (y, lift n e1, lift n e2)
  | Refl e -> Refl (lift n e)
  | Eq (e, e1, e2) -> Eq (lift n e, lift n e1, lift n e2)
  | Reflect (e1, e2) -> Reflect (lift n e1, lift n e2)
  | Explode (e1, e2) -> Explode (lift n e1, lift n e2)
  | e -> e

(* Unfolds all declared env constants and checks for naming conflicts *)
(* If marked as theorem or lemma they are left as they are *)

let rec unfold_all env vars = function
  | Global id -> 
    begin 
      match unfold id env with
      | Ok ((body, _), attrb) -> 
        if attrb = 1 then Ok (Global id) else Ok body
      | _ -> Ok (Global id)
    end

  | Lam (x, e) ->
    if is_declared x env then
      Error ("Naming conflict with the name '" ^ x ^ 
        "'\nIt occurs as definition/theorem identifier but is used as a variable name ")
    else
      begin match unfold_all env vars e with
      | Ok e' -> Ok (Lam (x, e'))
      | Error msg -> Error msg
      end

  | App (e1, e2) ->
    let u1 = unfold_all env vars e1 in
    let u2 = unfold_all env vars e2 in
    begin match u1, u2 with
      | Ok e1', Ok e2' -> Ok (App (e1', e2'))
      | Error msg, _ | _, Error msg -> Error msg
    end

  | Pi (x, e1, e2) -> 
    if is_declared x env then
      Error ("Naming conflict with the name '" ^ x ^ "'\nIt occurs as definition/theorem identifier but is used as a variable name ")
    else
      let u1 = unfold_all env vars e1 in
      let u2 = unfold_all env vars e2 in
      begin match u1, u2 with
      | Ok e1', Ok e2' -> Ok (Pi (x, e1', e2'))
      | Error msg, _ | _, Error msg -> Error msg
      end

  | Refl e ->
    let u1 = unfold_all env vars e in
    begin match u1 with
      | Ok e' -> Ok (Refl e')
      | Error msg -> Error msg
    end

  | Eq (e, e1, e2) -> 
    let u = unfold_all env vars e in
    let u1 = unfold_all env vars e1 in
    let u2 = unfold_all env vars e2 in
    begin match u, u1, u2 with
      | Ok e', Ok e1', Ok e2' -> Ok (Eq (e', e1', e2'))
      | Error msg, _, _ | _, Error msg , _ | _, _, Error msg -> Error msg
    end
  
  | Explode (e1, e2) ->
    let u1 = unfold_all env vars e1 in
    let u2 = unfold_all env vars e2 in
    begin match u1, u2 with
      | Ok e1', Ok e2' -> Ok (Explode (e1', e2'))
      | Error msg, _ | _, Error msg -> Error msg
    end

  | Reflect (e1, e2) ->
    let u1 = unfold_all env vars e1 in
    let u2 = unfold_all env vars e2 in
    begin match u1, u2 with
      | Ok e1', Ok e2' -> Ok (Reflect (e1', e2'))
      | Error msg, _ | _, Error msg -> Error msg
    end

  | e -> Ok e 