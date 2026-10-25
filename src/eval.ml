(**
  (c) Copyright 2019 Bruno Bentzen. All rights reserved.
  Released under Apache 2.0 license as described in the file LICENSE.

  Desc: Untyped weak head normal form reduction with β-reduction but not η-reduction. 
        η-conversion is only performed at unification stage to optimize reflection. 
        We also ι-reduce recursors of inductive families when they are fully applied to a constructor.
 **)

open Ast 
open Data
open Expr

(* Beta reduction without index shifting *)

let beta body arg =
  open_var 0 arg body

(* Break an application tree into head and argument list *)

let rec break_args acc = function
  | App (f, arg) -> break_args (arg :: acc) f
  | head -> (head, acc)

(* Rebuild application tree from head and argument list *)

let build_app head args =
  List.fold_left (fun acc arg -> App (acc, arg)) head args

(* Return the position of the constructor with the given name *)

let rec find_constructor_position c_name = function
  | [] -> None
  | c_spec :: rest ->
      if c_spec.c_name = c_name then
        Some 0
      else
        match find_constructor_position c_name rest with
        | Some index -> Some (index + 1)
        | None -> None

(* Reduces a well-applied recursor of an inductive family *)

let reduce_recursor rec_spec args =
  let num_minors = List.length rec_spec.constructors in
  let expected_args = rec_spec.num_params + 1 + num_minors + rec_spec.num_indices + 1 in

  if List.length args < expected_args then
    None (* Not fully applied yet *)
  else
    let indices, rest1 = Base.List.split_n args rec_spec.num_indices in
    let motive, rest2 = (List.hd rest1, List.tl rest1) in
    let minors, rest3 = Base.List.split_n rest2 num_minors in
    let params, major_list = Base.List.split_n rest3 rec_spec.num_params in
    let major = List.hd major_list in
    let extra_args = List.tl major_list in

    (* Breaks down the constructor head and arguments *)
    let head, c_args = break_args [] major in

    match head with
    | Global c_name ->
        (match List.find_opt (fun c -> c.c_name = c_name) rec_spec.constructors with
        | Some c_spec ->
            (* Strip the type family indices in constructor *)
            let actual_c_args =
              if List.length c_args > rec_spec.num_indices then
                snd (Base.List.split_n c_args rec_spec.num_indices)
              else c_args
            in
            (* Return the position of the constructor corresponding to c_name *)
            let ith = match find_constructor_position c_name rec_spec.constructors with
              | Some index -> index
              | None -> failwith "Constructor not found in rec_spec"
            in
            let minor_i = List.nth minors ith in
            
            (* Substitute constructor arguments and build IHs *)
            let reduced_args =
              (* TODO: Catch exceptions when lengths don't match *)
              List.fold_right2
                (fun arg is_rec acc ->
                  if is_rec then
                    (* Generate recursive call: rec_name indices motive minors params arg *)
                    let rec_call =
                      build_app
                        (Global (rec_spec.ind_name ^ "rec"))
                        (indices @ [motive] @ minors @ params @ [arg])
                    in
                    arg :: rec_call :: acc
                  else
                    arg :: acc)
                actual_c_args
                c_spec.c_rec_args
                []
            in
            let step = build_app minor_i reduced_args in
            Some (build_app step extra_args)
        | None -> None)
    | _ -> None

(* Weak head reduction: note that we dliberately never reduce i and j in 
   coercions and compositions either since users can only input atoms in 
   the raw syntax *)

let rec reduce = function
  | App (e1, e2) -> 
    let e1' = reduce e1 in
    (* First we attempt beta reduction *)
    begin match e1' with
    | Lam (_, e) ->
        reduce (beta e e2)
    | _ ->
      (* Then we attempt reduce recursor *)
      let e2' = reduce e2 in
      let full_app = App (e1', e2') in
      let head, args = break_args [] full_app in
      let recursor_opt =
        begin match head with
        | Global rec_name ->
            begin match Hashtbl.find_opt (fst (Data.get_ind_env ())) rec_name with
            | Some rec_spec ->
                begin match reduce_recursor rec_spec args with
                | Some reduced -> Some (reduce reduced)
                | None -> None
                end
            | None -> None
            end
        | _ -> None
        end
      in
      (* Lastly we output what was reduced *)
      begin match recursor_opt with
      | Some reduced -> reduced
      | None -> full_app
      end
    end

  | Type l -> Type (Level.reduce l)

  | e -> e

let eval = reduce