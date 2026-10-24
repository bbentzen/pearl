(**
  (c) Copyright 2019 Bruno Bentzen. All rights reserved.
  Released under Apache 2.0 license as described in the file LICENSE.

  Desc: The pretty printer supports special unicode characters, indents homogeneous compositions, 
        distinguishes between dependent and non-dependent functions and products,
        prints nested lambdas, pis, sigmas, and uses parentheses when necessary.
 **)

open Ast
open Expr

(* A simple pretty printer *)

(* TO DO: support user definitions. Here's an idea: first try to match expression with an 
   already defined expression (label def) in the global environment, proceed as usual if that fails *)

let rec print env = function
  | Global("star") -> "() "
  | Global("zero") -> "0 "
  | Global("nat") -> "ℕ "
  | App(App(App(App (Global "pair", _ ), _), e1), e2) -> 
    "(" ^ parenthesize env e1 ^ ", " ^ parenthesize env e2 ^ ") "
  | Global y -> y ^ " "
  | Local index -> name_at index env ^ " " (* "Local-" ^ (string_of_int index) ^ " " *)
    
  | Lam (x, e) -> 
    let rec iterate env = function
      | Lam (x', e') -> " " ^ x' ^ iterate (x' :: env) e'
      | e' -> ", " ^ print env e'
    in
    "λ " ^ x ^ iterate (x :: env) e

  | Pi (x, e1, e2) ->
    if occurs_index 0 0 e2 then
      let rec iterate env = function
        | Pi (x', e1', e2') ->
          if occurs_index 0 0 e2' then
            String.concat "" ["("; x'; " : "; print env e1'; ") "; iterate (x' :: env) e2']
          else
            String.concat "" [tparenthesize env e1'; "→ "; print (x' :: env) e2']
        | e' -> ", " ^ print env e'
      in
      "Π (" ^ x ^ " : " ^ print env e1 ^ ") " ^ iterate (x :: env) e2
    else
      begin match e2 with
        | Void() -> "¬" ^ tparenthesize env e1
        | _ ->
          let rec iterate env = function
            | Pi (_, e1', Void()) -> "¬" ^ tparenthesize env e1'
            | Pi (x', e1', e2') ->
              if occurs_index 0 0 e2' then
                String.concat "" ["Π ("; x'; " : "; print env e1'; ") "; print (x' :: env) e2']
              else
                String.concat "" [tparenthesize env e1'; "→ "; iterate (x' :: env) e2']
            | e' -> print env e'
          in
          tparenthesize env e1 ^ "→ " ^ iterate (x :: env) e2
      end
  
  (* Inductively-defined sigma type *)
  | App(App (Global "sigma", e1), Lam(x, e2)) ->
    if occurs_index 0 0 e2 then
      begin
      let rec iterate env = function
        | App(App (Global "sigma", e1'), Lam(x', e2')) ->
        (* | Sigma (x', e1', e2') -> *)
          if occurs_index 0 0 e2' then
            String.concat "" ["("; x'; " : "; print env e1'; ") "; iterate (x' :: env) e2']
          else
            String.concat "" [tparenthesize env e1'; "× "; print (x' :: env) e2']
        | e' -> ", " ^ print env e'
      in
      "Σ (" ^ x ^ " : " ^ print env e1 ^ ") " ^ iterate (x :: env) e2
      end
    else
      let rec iterate env = function
        | App(App (Global "sigma", e1'), Lam(x', e2')) ->
          if occurs_index 0 0 e2' then
            String.concat "" ["Σ ("; x'; " : "; print env e1'; ") "; print (x' :: env) e2']
          else
            String.concat "" [tparenthesize env e1'; "× "; iterate (x' :: env) e2']
        | e' -> print env e'
      in
      tparenthesize env e1 ^ "× " ^ iterate (x :: env) e2

  | Eq (e, e1, e2) ->
      parenthesize env e1 ^ " = " ^ parenthesize env e ^ parenthesize env e2

  | App (e1, e2) ->
      let rec iterate = function
      | App (e3, e4) -> iterate e3 ^ parenthesize env e4
      | e -> parenthesize env e
    in
    iterate e1 ^ parenthesize env e2

  | Type l -> 
    "type " ^ print_level l ^ " "
  
  | Quot (e1, e2) -> parenthesize env e1 ^ " / " ^ parenthesize env e2
  | Mkq (e1, e2) -> "[" ^ parenthesize env e1 ^ "] " ^ parenthesize env e2

  | Reflect (e1, e2) -> "reflect " ^ parenthesize env e1 ^ parenthesize env e2
  | ESubIn (e, e1, _) -> 
    (* print env e *)
  (* for testing: *)
  "[ " ^ parenthesize env e ^ "/ " ^ parenthesize env e1 ^ " ]"
  | Meta (n,_) -> "?" ^ string_of_int (abs n) ^ "? " (* negative indices are supressed from the user *)
  | Rfl () -> "rfl "
  | Void () -> "void "
  | Wild n -> "?_" ^ string_of_int n ^ "? "

and parenthesize env e = 
  let helper = function
    | Lam _ | Pi _ 
    | Reflect _ | App _
    | Eq _ -> true
    | _ -> false
  in
  if helper e then
    "(" ^ print env e ^ ") "
  else
    print env e


and tparenthesize env e = 
  let helper = function
    | Pi _ | App (App (Global "sigma", _), _) | Eq _ -> true
    | _ -> false
  in
  if helper e then
    "(" ^ print env e ^ ") "
  else
    print env e

and print_level = function
  | Num n -> string_of_int n
  | Suc n -> print_level n ^ "+ 1"
  | Var l -> l
  | Max (n, Num m) | Max (Num m, n) -> "max(" ^ print_level n ^ ", " ^ string_of_int m ^ ")"
  | Max (n, m) -> "max(" ^ print_level n ^ ", " ^ print_level m ^ ")"

(* Prints expressions in raw syntax form *)

let printf e = print [] e