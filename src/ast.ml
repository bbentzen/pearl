(**
  (c) Copyright 2019 Bruno Bentzen. All rights reserved.
  Released under Apache 2.0 license as described in the file LICENSE.

  Desc: This file governs the abstract syntax of parsed expressions and commands with named variables,
        as well as core expressions with de Bruijn indices for local variables, where binder names are 
        preserved as formatting hints for the pretty printer. It also processes raw into core expressions,
        where free identifiers remain globals and bound identifiers become local indices.
 **)

(* Raw syntax and operations used only at the parsing stage *)

type rawlevel = 
  | RNum of int
  | RVar of string
  | RSuc of rawlevel
  | RMax of rawlevel * rawlevel

type rawexpr = 
  | RId of string
  | RPi of string * rawexpr * rawexpr
  | RLam of string * rawexpr
  | RApp of rawexpr * rawexpr
  | REq of rawexpr * rawexpr * rawexpr
  | RRfl of unit
  | RQuot of rawexpr * rawexpr
  | RMkq of rawexpr * rawexpr
  | RVoid of unit
  | RType of rawlevel
  | RAnn of rawexpr * rawexpr 
  | RMeta of int
  | RWild of int
  | RReflect of rawexpr * rawexpr

let rec has_var x = function
  | RId y -> x = y
  | RPi (y, e1, e2)  -> if x = y then false else has_var x e1 || has_var x e2
  | RLam (y, e) -> if x = y then false else has_var x e 
  | RApp (e1, e2) | RQuot (e1, e2) | RMkq (e1, e2) | RReflect (e1, e2) -> 
    has_var x e1 || has_var x e2
  | REq (e, e1, e2) -> has_var x e || has_var x e1 || has_var x e2
  | _ -> false

let fresh_var_int e = 
  let rec helper i e =
    if has_var ("v" ^ string_of_int (i+1)) e then helper (i+1) e else i 
  in  (* not free_var *)
  helper 0 e

let fresh_var e1 e2 i =
  "v" ^ string_of_int (fresh_var_int (RApp (e1, e2)) + i)

(* The abstract syntax of commands takes raw expressions which are then converted to core expressions *)

type proof = 
  | Prf of string * (((string list * rawexpr) * bool) list) * rawexpr * rawexpr * int

type command = 
  | Import of command * string
  | Thm of command * proof
  | Infer of command * (((string list * rawexpr) * bool) list) * rawexpr
  | Ind of command * string * (((string list * rawexpr) * bool) list) * rawexpr * ((string * rawexpr) list)
  | Print of command * string
  | Eval of command * rawexpr
  | Level of command * string list
  | Eof of unit

(* Internal core syntax in locally nameless representation style *)

type level =
  | Num of int
  | Var of string
  | Suc of level
  | Max of level * level

type expr =
  | Local of int
  | Global of string
  | Pi of string * expr * expr
  | Lam of string * expr
  | App of expr * expr
  | Eq of expr * expr * expr
  | Rfl of unit
  | Quot of expr * expr
  | Mkq of expr * expr
  | Void of unit
  | Type of level
  | Ann of expr * expr (* explicit type annotations *)
  | Meta of int * bool (* bool is used in motive/index inference only *)
  | Wild of int
  | Reflect of expr * expr
  | ESubIn of expr * expr * expr

(* Conversion of raw expressions into expressions *)

let rec index_of x = function
  | [] -> None
  | y :: env -> if x = y then Some 0 else Option.map (fun n -> n + 1) (index_of x env)

let rec name_at n = function
  | [] -> "(ERROR: dangling local variable " ^ string_of_int n ^ ")"
  | x :: _ when n = 0 -> x
  | _ :: env -> name_at (n - 1) env

let rec level_of_raw = function
  | RNum n -> Num n
  | RVar x -> Var x
  | RSuc l -> Suc (level_of_raw l)
  | RMax (l1, l2) -> Max (level_of_raw l1, level_of_raw l2)

let rec to_raw_level = function
  | Num n -> RNum n
  | Var x -> RVar x
  | Suc l -> RSuc (to_raw_level l)
  | Max (l1, l2) -> RMax (to_raw_level l1, to_raw_level l2)

let rec of_raw_expr_with_env env = function
  | RId x ->
    begin
      match index_of x env with
      | Some index -> Local index
      | None -> Global x
    end
  | RPi (x, e1, e2) -> Pi (x, of_raw_expr_with_env env e1, of_raw_expr_with_env (x :: env) e2)
  | RLam (x, e) -> Lam (x, of_raw_expr_with_env (x :: env) e)
  | RApp (e1, e2) -> App (of_raw_expr_with_env env e1, of_raw_expr_with_env env e2)
  | RQuot (e1, e2) -> Quot (of_raw_expr_with_env env e1, of_raw_expr_with_env env e2)
  | RMkq (e1, e2) -> Mkq (of_raw_expr_with_env env e1, of_raw_expr_with_env env e2)
  | REq (e, e1, e2) -> Eq (of_raw_expr_with_env env e, of_raw_expr_with_env env e1, of_raw_expr_with_env env e2)
  | RRfl () -> Rfl ()
  | RVoid () -> Void ()
  | RType l -> Type (level_of_raw l)
  | RAnn (e1, e2) -> Ann (of_raw_expr_with_env env e1, of_raw_expr_with_env env e2)
  | RMeta n -> Meta (n, true)
  | RWild n -> Wild n
  | RReflect (e1, e2) -> Reflect (of_raw_expr_with_env env e1, of_raw_expr_with_env env e2)

(* Returns a core expression with a list of used variable identifiers *)

let rec of_raw_expr_with_vars env = function
  | RId x ->
    (* Stores integers n for every identifier of the form "v" ^ n *)
    let e = 
      begin match index_of x env with
      | Some index -> Local index
      | None -> Global x
      end 
    and n = 
      if x.[0] = 'v' then
        let s = Base.String.drop_prefix x 1 in
        begin match int_of_string_opt s with
            | Some n -> [n]
            | None -> []
        end
      else 
        []
    in
    e, n
  | RPi (x, e1, e2) ->
    let e1', v1 = of_raw_expr_with_vars env e1 in
    let e2', v2 = of_raw_expr_with_vars (x :: env) e2 in
    Pi (x, e1', e2'), v1 @ v2
  | RLam (x, e) ->
    let e', v = of_raw_expr_with_vars (x :: env) e in
    Lam (x, e'), v
  | RApp (e1, e2) ->
    let e1', v1 = of_raw_expr_with_vars env e1 in
    let e2', v2 = of_raw_expr_with_vars env e2 in
    App (e1', e2'), v1 @ v2
  | REq (e, e1, e2) ->
    let e', v = of_raw_expr_with_vars env e in
    let e1', v1 = of_raw_expr_with_vars env e1 in
    let e2', v2 = of_raw_expr_with_vars env e2 in
    Eq (e', e1', e2'), v @ v1 @ v2
  | RRfl () -> Rfl (), []
  | RQuot (e1, e2) ->
    let e1', v1 = of_raw_expr_with_vars env e1 in
    let e2', v2 = of_raw_expr_with_vars env e2 in
    Quot (e1', e2'), v1 @ v2
  | RMkq (e1, e2) ->
    let e1', v1 = of_raw_expr_with_vars env e1 in
    let e2', v2 = of_raw_expr_with_vars env e2 in
    Mkq (e1', e2'), v1 @ v2
  | RVoid () -> Void (), []
  | RType l -> Type (level_of_raw l), []
  | RAnn (e1, e2) ->
    let e1', v1 = of_raw_expr_with_vars env e1 in
    let e2', v2 = of_raw_expr_with_vars env e2 in
    Ann (e1', e2'), v1 @ v2
  | RMeta n -> Meta (n, true), []
  | RWild n -> Wild n, []
  | RReflect (e1, e2) ->
    let e1', v1 = of_raw_expr_with_vars env e1 in
    let e2', v2 = of_raw_expr_with_vars env e2 in
    Reflect (e1', e2'), v1 @ v2

let fresh_var_list l =
  List.fold_left (fun acc n -> n + acc) 0 l

let of_raw_expr e = fst (of_raw_expr_with_vars [] e)