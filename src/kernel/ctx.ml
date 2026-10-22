(**
  (c) Copyright 2019 Bruno Bentzen. All rights reserved.
  Released under Apache 2.0 license as described in the file LICENSE.

  Desc: Checks whether a given context is well-formed.
 **)

open Basis
open Context
open Eval

let check global ctx ind lvl =
  let rec helper l = 
    match l with
  | [] -> Ok []
  | (x, ty, b) :: ctx' ->
    match Env.unfold_all global 0 ty with
    | Error msg -> Error ("The specified context is invalid: " ^ msg)
    | Ok ty' ->
      (* Dumps inductive type data into the context (reversed to preserve its order ) *)
      (* let ind_ctx = List.map (fun (id, ty) -> (id, ty, true)) ind @ (List.rev ctx') in *)
      match Type.check global (List.rev ctx) ind lvl ty', helper ctx' with
      | Ok elab, Ok ctx'' -> 
        if Env.is_declared x global then
          Error ("Naming conflict with the identifier '" ^ x ^ 
            "'\nIt occurs as a definition/theorem name but is declared as a local variable")
        else
          Ok ((x, eval (fst elab), b) :: ctx'')
      | Error msg, _ -> Error ("The specified context has a type mismatch: " ^ msg)
      | _ , Error msg -> Error msg
  in
  helper (List.rev ctx)

let check_with_universe global ctx ind lvl =
  let rec helper l = 
    match l with
  | [] -> Ok ([], [])
  | (x, ty, b) :: ctx' ->
    match Env.unfold_all global 0 ty with
    | Error msg -> Error ("The specified context is invalid: " ^ msg)
    | Ok ty' ->
      match Type.check global ctx' ind lvl ty', helper ctx' with
      | Ok (ty', univ), Ok (ctx1, ctx2) -> 
        if Env.is_declared x global then
          Error ("Naming conflict with the identifier '" ^ x ^ 
            "'\nIt occurs as a definition/theorem name but is declared as a local variable")
        else
          Ok (((x, eval ty', b) :: ctx1), ((x, eval univ, b) :: ctx2))
      | Error msg, _ -> Error ("The specified context is invalid: " ^ msg)
      | _ , Error msg -> Error msg
  in
  helper (List.rev ctx)

let rec placeholder_levels = function
  | [] -> []
  | (x, ty, b) :: ctx' ->
    (x, Level.placeholder_levels ty, b) :: placeholder_levels ctx'