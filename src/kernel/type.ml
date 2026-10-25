(**
  (c) Copyright 2019 Bruno Bentzen. All rights reserved.
  Released under Apache 2.0 license as described in the file LICENSE.

  Desc: Checks whether an expression is a type
        Allows for placeholders to stand for types.
 **)

open Basis
open Ast
open Eval

let check global ctx ind lvl ty =
  match ty with
  | Meta (n, b) -> Ok (Meta (n, b), ty)
  | _ ->
    let ty' = eval ty in
    let h1 = Placeholder.generate () in
    match Elab.elaborate global ctx ind lvl 0 ([], []) h1 1 ty' with
    | Error (_, msg) -> Error ("Failed typehood check. \n" ^ msg)
    | Ok (ty', tTy, _) ->
      match tTy with
        | Type _ -> Ok (ty', tTy)
        | Meta _ -> Ok (ty', tTy) (* Meta _ has been added for tests *)
        | _ -> Error ("Failed to prove that \n  " ^ Pretty.printf ty' ^ "\nis a type")
    