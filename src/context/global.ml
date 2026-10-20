(**
  (c) Copyright 2019 Bruno Bentzen. All rights reserved.
  Released under Apache 2.0 license as described in the file LICENSE.

  Desc: This file handles operations on the context and converts precontexts to actual contexts, 
        which are lists (string * expr * bool) where the strings are global variables 
        in the locally nameless representation style.     
 **)

open Basis
open Ast
open Expr

(* Replaces a global variable x with a given expression d *)

let rec subst_global k d x = function
  | Global y when x = y -> shift 0 k d
  | Global _ | Local _ | Void _ | Rfl _ | Type _ | Meta _ | Wild _ as e -> e
  | Pi (y, e1, e2) -> Pi (y, subst_global k d x e1, subst_global (k+1) d x e2)
  | Lam (y, e) -> Lam (y, subst_global (k+1) d x e)
  | App (e1, e2) -> App (subst_global k d x e1, subst_global k d x e2)
  | Eq (e, e1, e2) -> Eq (subst_global k d x e, subst_global k d x e1, subst_global k d x e2)
  | Quot (e1, e2) -> Quot (subst_global k d x e1, subst_global k d x e2)
  | Mkq (e1, e2) -> Mkq (subst_global k d x e1, subst_global k d x e2)
  | Reflect (e1, e2) -> Reflect (subst_global k d x e1, subst_global k d x e2)
  | Explode (e1, e2) -> Explode (subst_global k d x e1, subst_global k d x e2)
  | ESubIn (e, e1, e2) -> ESubIn (subst_global k d x e, subst_global k d x e1, subst_global k d x e2)

(* Creates a context (a list (string * expr * bool)) from a list (string list * raw expr * bool) *)

let rec create_ctx = function
  | [] -> []
  | ((ids, ty), b) :: l ->
    begin match ids with
      | [] -> []
      | e :: ids' ->
        let ty' = of_raw_expr ty in
        (e, ty', b) :: create_ctx ([((ids', ty), b)]) @ create_ctx l 
        (* this can be optimized since you don't want to translate the same type 
        over and over again when parsing identifiers of the same type*)
    end

(* Determines whether a variable has been declared *)

let is_declared x ctx =
  let rec helper x = function
    | [] -> false
    | (y, _, _) :: ctx -> 
      if x = y then
        true
      else
        helper x ctx
  in
  helper x (List.rev ctx)

let rec var_type x ctx =
  match (List.rev ctx) with
  | [] -> Error()
  | (y, ty, _) :: ctx' -> 
    if x = y then 
      Ok ty
    else 
      var_type x ctx'

(* Determines whether a given typed variable occurs in the context *)

let rec check_var_ty x ty ctx =
  match (List.rev ctx) with
  | [] -> false 
  | (y, ty', _) :: ctx -> 
    if x = y && ty' = ty then 
      true
    else
      check_var_ty x ty ctx

(* Finds a variable of a given type in the context when it exists *)

let find_ty ty ctx =
  let rec helper ty = function
    | [] -> Error () 
    | (y, ty', _) :: ctx -> 
      if ty' = ty then 
        Ok y
      else 
        helper ty ctx
  in
  helper ty (List.rev ctx)

let find_true ty ctx =
  let rec helper ty = function
    | [] -> Error () 
    | (y, ty', b) :: ctx' -> 
      if ty' = ty && b then 
        Ok y
      else 
        helper ty ctx'
  in
  helper ty (List.rev ctx)

(* Prints the context *)

let print ctx = 
  let rec printrev = function
    | [] -> "" 
    | (id, ty, _) :: ctx -> 
      " " ^ id ^ " : " ^ Pretty.printf ty ^ "\n" ^ printrev ctx
  in
  printrev (List.rev ctx)

let printf ctx = print ctx

(* Use syntactic identity? Probably too strong *)

let rec equiv_lookup rel = function
  | [] -> []
  | (_, App (Global "is_equiv", e), _) :: ctx -> e :: equiv_lookup rel ctx
  | _ :: ctx -> equiv_lookup rel ctx
