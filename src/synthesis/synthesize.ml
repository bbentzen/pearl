(**
  (c) Copyright 2019 Bruno Bentzen. All rights reserved.
  Released under Apache 2.0 license as described in the file LICENSE.
  
  Desc: Handles synthesization of implicit arguments and universe levels,
         Performs an exhaustive search on compatible types based on the context
         The elaborator returns a pair (sl') of its current synthesization attempts and stack
 **)

open Basis
open Eval
open Kernel

(* Iterated synthesization attempts *)

let rec check global ctx ind lvl sl e ty max vars =
  let e = eval e and ty = eval ty in
  match Elab.elaborate global ctx ind lvl 0 sl ty vars e with
  | Ok (e', ty', _) ->
    let e' = Placeholder.solve [] e' in
    let ty' = Placeholder.solve [] ty' in
    Hashtbl.clear Data.meta_store;
    (* Type check the fully elaborated term *)
    let e' = Expr.reset e' in
    (* let ty' = Expr.reset ty' in *)
      begin match Elab.elaborate global ctx ind lvl 0 ([], []) ty vars e' with
      | Ok (e', ty', sl) ->
        (* Need to find a better way to avoid rezonking *)
        let e' = Placeholder.solve [] e' in
        let ty' = Placeholder.solve [] ty' in
        (* Double checks that there are no placeholders left in the synthesization attempts *)
        Hashtbl.clear Data.meta_store;
        if Attempt.trustworthy (fst sl) then
          let e' = Expr.realizer_of e' in
          let ty' = Expr.realizer_of ty' in
          Ok (e', ty')
        else
          Error ("Untrustworthy synthesization attempt with " ^ Attempt.printfst (fst sl) ^ "\nYou should not see this message, please report.")
      | Error (_, msg) -> Error ("Cannot typecheck that the fully elaborated term\n  " ^ Pretty.printf e' ^ "\n has the fully elaborated type\n  " ^ Pretty.printf ty' ^ "\nTypechecking failed for the following reasons: " ^ msg)
      end
  | Error (sl, msg) -> iter sl msg global ctx ind lvl e ty (max+1) vars

and iter sl' msg global ctx ind lvl e ty max vars =
  if max > 100 then
    Error "Maximum number of synthetization steps reached\n(You should not see this message, please report)"
  else
    let current, past = sl' in
    match current with
    | [] -> Error msg
    | (n, id, _) :: current' ->
      let e' = Expr.fullsubst 0 (Wild n) (Global id) e in
      let w = check global ctx ind lvl ([], past) e' ty max vars in 
      match w with
      | Ok (e', ty') -> Ok (e', ty')
      | Error _ -> check global ctx ind lvl (current', (n, id) :: past) e ty max vars

let init global ctx ind lvl e ty vars =
  check global ctx ind lvl ([], []) e ty 0 vars