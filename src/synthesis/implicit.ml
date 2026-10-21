(**
  (c) Copyright 2019 Bruno Bentzen. All rights reserved.
  Released under Apache 2.0 license as described in the file LICENSE.
  
  Desc: Reads implicit arguments by enumerating them
 **)

open Basis
open Ast

(* Replaces 0-indexed wildcards with uniquely assigned indices starting at n *)

let rec read n = function
  | Wild 0 -> Wild n, n+1 
  | Wild m -> Wild m, n+m
  | Pi (y, e1, e2) ->
    let r_e1 = read n e1 in
    let r_e2 = read (snd r_e1) e2 in
    Pi (y, fst r_e1, fst r_e2), snd r_e2
  | Lam (y, e) ->
    let r_e = read n e in
    Lam (y, fst r_e), snd r_e
  | App (e1, e2) ->
    let r_e1 = read n e1 in
    let r_e2 = read (snd r_e1) e2 in
    App (fst r_e1, fst r_e2), snd r_e2
  | Eq (e, e1, e2) ->
    let r_e = read n e in
    let r_e1 = read (snd r_e) e1 in
    let r_e2 = read (snd r_e1) e2 in
    Eq (fst r_e, fst r_e1, fst r_e2), snd r_e2
  | Quot (e1, e2) ->
    let r_e1 = read n e1 in
    let r_e2 = read (snd r_e1) e2 in
    Quot (fst r_e1, fst r_e2), snd r_e2
  | Mkq (e1, e2) ->
    let r_e1 = read n e1 in
    let r_e2 = read (snd r_e1) e2 in
    Mkq (fst r_e1, fst r_e2), snd r_e2
  | Reflect (e1, e2) ->
    let r_e1 = read n e1 in
    let r_e2 = read (snd r_e1) e2 in
    Reflect (fst r_e1, fst r_e2), snd r_e2
  | ESubIn (e, e1, e2) ->
    let r_e = read n e in
    let r_e1 = read (snd r_e) e1 in
    let r_e2 = read (snd r_e1) e2 in
    ESubIn (fst r_e, fst r_e1, fst r_e2), snd r_e2
  | e -> e, n

let convert e = fst (read 1 e)