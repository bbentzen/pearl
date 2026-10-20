(**
  (c) Copyright 2019 Bruno Bentzen. All rights reserved.
  Released under Apache 2.0 license as described in the file LICENSE.

  Desc: This module contains the elaborator, type checker, type inference, and unifier.
        The elaborator performs ambiguously elaboration, type checking, and type inference.
        The unifier implements the eta conversion.
 **)

open Basis
open Context
open Ast
open Eval

let st = Constraints.empty ()

let solve_meta_application args vars body = function
  | Meta n ->
    let rec build_lam vars body = function
      | [] -> body
      | _ :: args -> 
        let v1 = Expr.init_fresh vars in
        Lam (v1, build_lam (vars + 1) (Expr.shift 1 0 body) args)
    in
    if Placeholder.has_placeholder_name n body then None else
      let solved = build_lam vars body args in
      (Hashtbl.add Data.meta_store n { Data.solution = solved}; Some solved)
  | _ -> None

(* Checks whether the type of a given expression is the given type *)

let rec elaborate env ctx lvl lc sl ty vars = function
  | Global x ->
    begin match Global.var_type x ctx with
    | Ok ty' ->
      let ty = eval ty in
      let c = Global.check_var_ty x ty ctx in
      let h = Placeholder.is ty in 
      let h' = Placeholder.is ty' in 
      let d = Global.is_declared x ctx in
      begin match c, h, h', d with
      | true , _, _ , _ | _ , _, true , _ -> Ok (Global x, ty, sl)
      | _ , true, _ , _ -> Ok (Global x, ty', sl)
      | false , false, false , true ->
        let h1 = Placeholder.generate () in
        begin match elaborate env ctx lvl lc sl h1 vars ty' with
        | Ok (_, tTy', sa) ->
          begin match unify env ctx lvl lc sl vars (ty, ty', (Expr.type_of tTy')) true with
          | Ok s -> Ok (Global x, s, sl) 
          | Error _ ->
            (* Try again after evaluating both types *)
            let ty = eval ty and ty' = eval ty' in
            begin match unify env ctx lvl lc sl vars (eval ty, eval ty', (Expr.type_of tTy')) true with
            | Ok s -> Ok (Global x, s, sl) 
            | Error (_, msg) -> Error (sa, Msg.var_type_mismatch x ty' ty msg)
            end
          end
        | Error (sa, msg) -> Error (sa, Msg.var_error x msg)
        end
      | false, false, false, false -> Error (sl, Msg.var_error_2 x)
      end
    | Error _ ->
      (* Check if identifier corresponds to a theorem in the env environment *)
      begin match Env.var_type x env with
      | Ok envty ->
          let h1 = Placeholder.generate () in
          begin match unify env ctx lvl lc sl vars (eval ty, envty, h1) true with
          | Ok s ->
            Ok (Global x, s, sl) 
          | Error (_, msg) -> Error (([],[]), Msg.var_type_mismatch x envty ty msg)
          end
      | Error _ -> Error (sl, Msg.undeclared x)
      end
    end

  | Lam (x, e) ->
    let e = eval e in
    let ty = eval ty in
    (* When there is no eta-conversion we expect a function type *)
    let lam_check x e ty =
      begin match (Expr.type_of ty) with
      | Pi (_, ty1, ty2) ->
        let v1 = Expr.mk_fresh x ctx in
        let e' = Expr.open_var 0 (Global v1) e in
        let ty2' = Expr.open_var 0 (Global v1) ty2 in
        let elab = elaborate env ((v1, ty1, true) :: ctx) lvl lc sl ty2' (vars+1) e' in
        begin match elab with
        | Ok (e', ty2', sa) -> Ok (Lam (v1, Expr.close_bound v1 e'), Pi (v1, ty1, Expr.close_bound v1 ty2'), sa)
        | Error (sa, msg) -> Error (sa, msg)
        end
      | Meta _ ->
        let h1 = Placeholder.generate () in
        let h2 = Placeholder.generate () in
        elaborate env ctx lvl lc sl (Pi(x, h1, h2)) vars (Lam (x, e))
      | _ -> Error (sl, Msg.lam_error x e ty)
      end
    in
    (* First, we isolate Lam (x, App (e1 x)) and check for eta-conversion *)
    begin match e with
    | App (e, Local 0) ->
      if not (Expr.occurs_index 0 0 e) && not (Placeholder.has e) then 
        (* Elaborate e1 against ty without expecting a function type *)
        (* Flag the toleration of dangling local when reflecting or exploding *)
        begin match elaborate env ctx lvl (lc+1) sl ty vars e with
        | Ok (e, ty, sa) -> Ok (Lam (x, App (e, Local 0)), ty, sa)
        | Error msg -> Error msg
        end
      else
        lam_check x (App (e, Local 0)) ty
    | e ->
      lam_check x e ty
    end

  | App (e1, e2) ->
    (* If the head expression is a recursor try to infer the motive *)
    let ty = eval ty in
    let head, args = Eval.break_args [] (App (e1, e2)) in
    let rec_env, cons_env = Data.get_ind_env () in 
    begin match Infer.rec_motive_idx elaborate env ctx lvl lc sl vars rec_env ty args head with
    | Some res ->
      elaborate env ctx lvl lc sl ty vars res
    | None ->
      (* If the head expression is a constructor try to infer indices *)
      begin match Infer.constr_indices cons_env ty args head with
      | Some res ->
        elaborate env ctx lvl lc sl ty vars res
      | None ->
        (* Otherwise infer the type of e1 and check its evaluated domain against e2 *)
        let h1 = Placeholder.generate () in
        let v1 = Expr.init_fresh vars in
        let h2 = Placeholder.generate () in
        let elab1 = elaborate env ctx lvl lc sl (Pi(v1, h1, h2)) (vars+1) e1 in
        begin match elab1 with
        | Ok (e1', Pi(_, ty1, ty2), sa1) ->
          (* Evaluates the inferred domain before type checking *)
          let ty1' = eval ty1 in
          let h3 = Placeholder.generate () in
          let elab2 = elaborate env ctx lvl lc sl ty1' (vars+1) e2 in
          begin match elab2 with
          | Ok (e2', _, sa2) ->
            (* Otherwise unify both types possibly lifting the universe levels *)
            let ty2' = eval (Expr.open_var 0 e2' ty2) in
            begin match unify env ctx lvl lc sl (vars+1) (ty, ty2', h3) true with
            | Ok _ -> Ok (App (e1', e2'), ty2', Stack.append sa1 sa2)
            | Error (_, msg) -> Error (Stack.append sa1 sa2, Msg.app_fail_1 e1' e2' ty2' ty msg)
            end
          | Error (sa2, msg) -> Error (Stack.append sa1 sa2, Msg.app_fail_2 e1 e2 ty1' msg)
          end
        | Ok (e1', ty1', sa1) -> 
          begin match elaborate env ctx lvl lc sl h1 (vars+1) e2 with
          | Ok (e2', ty1, sa2) ->
            Constraints.add st {
            lhs = (Pi(v1, ty1, h2)); 
            rhs = ty1'; 
            cty = Type(Var "?_"); 
            clift = true };
            let ty2' = eval (Expr.open_var 0 e2' h2) in
            (* Delay unification *)
            Ok (App (e1', e2'), ty2', Stack.append sa1 sa2)
          | Error (sa2, msg) -> Error (Stack.append sa1 sa2, Msg.app_fail_2 e1 e2 ty1' msg)
          end
        | Error (sa, msg) -> Error (sa, Msg.app_wrong_ty2 e1 msg)
        end
      end
    end
  
  | Reflect (e1, e2) ->
    let e1 = eval e1 in
    let e2 = eval e2 in
    let h1 = Placeholder.generate () in
    begin match elaborate env ctx lvl lc sl h1 vars e1 with
    | Ok (e1, ty1, sa) ->
      let ty1 = Placeholder.solve [] ty1 in
      begin match eval (Expr.type_of ty1) with
      | Eq (_, Pi(_, a, a'), Pi(_, b, b')) ->
        eq_reflection_on env ctx lvl lc sl ty vars e1 e2 ([(a, b)] @ [(a', b')])
      | Eq (_, Eq(ty1, a, a'), Eq(ty1', b, b')) ->
        eq_reflection_on env ctx lvl lc sl ty vars e1 e2 ([(ty1, ty1')] @ [(a, b)] @ [(a', b')])
      | Eq (_, a, b) ->
        eq_reflection_on env ctx lvl lc sl ty vars e1 e2 [(a, b)]
      | App (App (rel, a), b) ->
        if find_equivalence env ctx lvl lc sl vars rel h1 then
          eq_reflection_on env ctx lvl lc sl ty vars e1 e2 [(a, b)]
        else
          Error (sa, Msg.reflect_goal_mkq ctx e1 rel a b ty)
      | ty1 -> Error (sa, Msg.reflect_1 e1 ty1)
      end
    | Error (sa, msg) -> Error (sa, Msg.reflect_2 e1 msg)
    end

  | Explode (e1, e2) ->
    begin match elaborate env ctx lvl lc sl (Void()) vars e1 with
    | Ok (e1', _, sa) -> Ok (Explode (e1', e2), ty, sa)
    | Error (sa, msg) -> Error (sa, Msg.void_error e1 msg)
    end
  
  | ESubIn (e, e1, e2) ->
    begin match elaborate env ctx lvl lc sl ty vars e with
    | Ok (e, ty, sa) -> Ok (ESubIn (e, e1, e2), ty, sa)
    | Error (sa, msg) -> Error (sa, Msg.esub_error msg)
    end
  
  | Local index ->
    if index < lc then Ok (Local index, ty, sl) else
      Error (sl, Msg.unexpected index ty ctx)

  | Rfl () ->
    let ty = eval ty in
    begin match (Expr.type_of ty) with
    | Eq (ty1, e1, e2) ->
      let elab1 = elaborate env ctx lvl lc sl ty1 vars e1 in
      let elab2 = elaborate env ctx lvl lc sl ty1 vars e2 in
      begin match elab1, elab2 with
      | Ok (e1, _, sa), Ok (e2, _, sb) ->
        let e1 = eval e1 in 
        let e2 = eval e2 in
        begin match unify env ctx lvl lc sl vars (e1, e2, (Expr.type_of ty1)) false with
          | Ok _ -> Ok (Rfl (), Eq (ty1, e1, e2), Stack.append sa sb)
          | Error (_, msg) -> Error (Stack.append sa sb, msg)
        end
      | Error (sl, msg), _ -> Error (sl, Msg.rfl_error_1 ty msg)
      |  _ , Error (sl, msg) -> Error (sl, Msg.rfl_error_1 ty msg)
      end

    | Meta n ->
      let h1 = Placeholder.generate () in
      let h2 = Placeholder.generate () in
      Hashtbl.add Data.meta_store n { Data.solution = Eq (h2, h1, h1)};
      Ok (Rfl (), Eq (h2, h1, h1), sl)
    | _ -> Error (sl, Msg.rfl_error_2 ty)
    end

  | Pi(x, ty1, ty2) ->
    let ty1 = eval ty1 in
    let h1 = Level.ignore_meta ty in
    let elab1 = elaborate env ctx lvl lc sl h1 vars ty1 in
    let ty2 = eval ty2 in
    let ty2' = (Expr.open_var 0 (Global x) ty2) in
    let elab2 = elaborate env ((x, ty1, true) :: ctx) lvl lc sl h1 vars ty2' in
    begin match elab1, elab2 with
    | Ok (ty1', Type n1, sa1), Ok (ty2', Type n2, sa2) -> 
      let max = Level.reduce (Max(n1, n2)) in
      begin match (Expr.type_of ty) with
      | Type (Var par) when Level.is_arbitrary_string par ->
        (* Synthesize type levels placeholder *)
        Ok (Pi(x, ty1', Expr.close_bound x ty2'), Type max, Stack.append sa1 sa2)
      | Type m ->
        (* Check if levels are compatible *)
        if Level.leq max m then 
          Ok (Pi(x, ty1', Expr.close_bound x ty2'), Type m, Stack.append sa1 sa2)
        else 
          Error (Stack.append sa1 sa2, Msg.pi_universe_1 x ty1 ty2 max m)
      | Meta n ->
        Hashtbl.add Data.meta_store n { Data.solution = Type max};
        Ok (Pi(x, ty1', Expr.close_bound x ty2'), Type max, Stack.append sa1 sa2)
      | _ -> Error (Stack.append sa1 sa2, Msg.pi_universe_2 x ty1 ty2 ty)
      end
    (* Store these Ok'd metas? *)
    | Ok (ty1', Type n, sa), Ok (ty2', Meta _, _) 
    | Ok (ty1', Meta _, sa), Ok (ty2', Type n, _) -> 
      begin match (Expr.type_of ty) with
      | Type m ->
        if Level.leq n m then 
          Ok (Pi(x, ty1', Expr.close_bound x ty2'), Type m, sa) 
        else 
          Error (sa, Msg.pi_universe_1 x ty1 ty2 n m)
      | Meta k -> 
        Hashtbl.add Data.meta_store k { Data.solution = Type n}; 
        Ok (Pi(x, ty1', Expr.close_bound x ty2'), Type n, sa)
      | _ -> Error (sa, Msg.pi_universe_2 x ty1 ty2 ty)
      end
    
    | Ok (ty1', Type n, sa), Ok (Meta k, _, _) -> 
      begin match (Expr.type_of ty) with
      | Type m ->
        if Level.leq n m then 
          Ok (Pi(x, ty1', Meta k), Type m, sa) 
        else 
          Error (sa, Msg.pi_universe_1 x ty1 ty2 n m)
      | Meta l ->
        Hashtbl.add Data.meta_store l { Data.solution = Type n}; 
        Ok (Pi(x, ty1', Meta k), Type n, sa) (* TODO: hole might live in a higher universe *)
      | _ -> Error (sa, Msg.pi_universe_2 x ty1 ty2 ty)
      end
    | Ok (Meta k, _, _), Ok (ty2', Type n, sa) -> 
      begin match (Expr.type_of ty) with
      | Type m ->
        if Level.leq n m then 
          Ok (Pi(x, Meta k, Expr.close_bound x ty2'), Type m, sa) 
        else 
          Error (sa, Msg.pi_universe_1 x ty1 ty2 n m)
      | Meta l ->
        Hashtbl.add Data.meta_store l { Data.solution = Type n}; 
        Ok (Pi(x, Meta k, Expr.close_bound x ty2'), Type n, sa) (* TODO: hole might have live in a higher universe *)
      | _ -> Error (sa, Msg.pi_universe_2 x ty1 ty2 ty)
      end
    | Ok (Meta k1, _, _), Ok (Meta k2, _, _) ->
      begin match (Expr.type_of ty) with
      | Type m -> Ok (Pi(x, Meta k1, Meta k2), Type m, sl) 
      | Meta k -> Ok (Pi(x, Meta k1, Meta k2), Meta k, sl)
      | _ -> Error (sl, Msg.pi_universe_2 x ty1 ty2 ty)
      end
    
    | Ok (_, Type _, sa), Error (sb, msg) -> Error (Stack.append sa sb, Msg.pi_codomain ty2' msg)
    | _, Error (sb, msg) -> Error (sb, Msg.pi_codomain ty2' msg)
    | Error (sa, msg), _ -> Error (sa, Msg.pi_domain ty1 msg)
    | Ok (ty1', u1, _), Ok (ty2', u2, _) -> 
      let ty1' = Placeholder.solve [] ty1' in
      let ty2' = Placeholder.solve [] ty2' in
      let u1 = Placeholder.solve [] u1 in
      let u2 = Placeholder.solve [] u2 in
      Error (sl, Msg.pi_unexpected x ty1 ty2 ty ty1' u1 ty2' u2)
    end

  | Void() ->
    let ty = eval ty in
    begin match (Expr.type_of ty) with
    | Type m -> Ok (Void(), Type m, sl)
    | Meta k -> 
      Hashtbl.add Data.meta_store k { Data.solution = Type (Num 0)}; 
      Ok (Void(), Type (Num 0), sl)
    | _ -> Error (sl, Msg.void_ty ty)
    end
  
  | Quot(e1, e2) -> 
    let e1 = eval e1 in
    let e2 = eval e2 in
    let h1 = Level.ignore_meta ty in
    begin match elaborate env ctx lvl lc sl h1 vars e1 with
    | Ok (e1, Type n, st) ->
      let ty1 = Pi("?v", e1, Pi("?v", e1, Type n)) in
      begin match elaborate env ctx lvl lc sl ty1 vars e2 with
      | Ok (e2, Pi(_, e1, Pi(_, e1', Type n)), sa) ->
        (* Only proceed only if a proof of equivalence is available *)
        if find_equivalence env ctx lvl lc sl vars e2 ty1 then
          let e1 = Placeholder.without e1 e1' in
          match eval (Expr.type_of ty) with
          | Type (Var par) when Level.is_arbitrary_string par ->
            (* Synthesize type levels placeholder *)
            Ok (Quot(e1, e2), Type n, Stack.append st sa)
          | Type m ->
            (* Check if levels are compatible *)
            if Level.leq n m then
              Ok (Quot(e1, e2), Type m, Stack.append st sa)
            else
              Error (Stack.append st sa, Msg.quot_universe_1 e1 e2 n m)
          | Meta k ->
            Hashtbl.add Data.meta_store k { Data.solution = Type n};
            Ok (Quot(e1, e2), Type n, Stack.append st sa)
          | _ -> Error (Stack.append st sa, Msg.quot_universe_2 e1 e2 (eval (Expr.type_of ty)))
        else
          Error (sa, Msg.quot_no_rel_3 e1 e2)
      | Ok (e2, ty1, _) -> Error (sl, Msg.quot_no_rel_1 e1 e2 n ty1)
      | Error (sl, msg) -> Error (sl, Msg.quot_no_rel_2 e1 e2 n msg)
      end
    (* Type is neither a well-specified universe nor a meta *)
    | Ok (e1, ty1, st) -> Error (st, Msg.quot_dom_type_1 e1 e2 ty1)
    | Error (sa, msg) -> Error (sa, Msg.quot_dom_type_2 e1 e2 msg)
    end
   
  | Mkq (e1, e2) ->
    let ty = eval ty in
    begin match (Expr.type_of ty) with
    | Quot (ty1, e2') ->
      let e1 = eval e1 in
      begin match elaborate env ctx lvl lc sl ty1 vars e1 with
      | Ok (e1, ty1, sa) ->
        let e2 = eval e2 in
        let ty2 = Pi("?v", ty1, Pi("?v", ty1, Type (Var "?_"))) in
        begin match unify env ctx lvl lc sl vars (e2', e2, ty2) true with
        | Ok e2 -> Ok (Mkq (e1, e2), Quot (ty1, e2), sa)
        | Error (_, msg) -> Error (sl, Msg.mkq_error_rel e1 e2 ty msg)
        end
      | Error (sa, msg) -> Error (sa, Msg.mkq_error_dom e1 e2 ty ty1 msg)
      end
    | Meta _ ->
      let h1 = Placeholder.generate () in
      begin match elaborate env ctx lvl lc sl h1 vars e1 with
      | Ok (e1, ty1, sa) ->
        let e2 = eval e2 in
        let ty1 = Pi("?v", ty1, Pi("?v", ty1, Type (Var "?_"))) in
        begin match elaborate env ctx lvl lc sl ty1 vars e2 with
        | Ok (e2, Pi(_, ty1, Pi("?v", ty1', _)), sa) ->
          let ty1 = Placeholder.without ty1 ty1' in
          Ok (Mkq (e1, e2), Quot (ty1, e2), sa)
        | Ok _ -> Error (sa, Msg.mkq_error_rel_2 e1 e2 ty)
        | Error (sa, msg) -> Error (sa, Msg.mkq_error_rel e1 e2 ty msg)
        end
      | Error (sa, msg) -> Error (sa, Msg.mkq_error_dom_2 e1 e2 ty msg)
      end
    | _ -> Error (sl, Msg.mkq_error_ty e1 e2 ty)
    end

  | Eq(ty1, e1, e2) ->
    let ty1 = eval ty1 in
    let e1 = eval e1 in
    let e2 = eval e2 in
    let h1 = Placeholder.generate () in
    let elab = elaborate env ctx lvl lc sl h1 vars ty1 in
    begin match elab with
    | Ok (ty1, Type n, st) -> 
      let elab1 = elaborate env ctx lvl lc sl ty1 vars e1 in
      let elab2 = elaborate env ctx lvl lc sl ty1 vars e2 in
      begin match elab1, elab2 with
      | Ok (e1, _, sa), Ok (e2, _, sb) ->
        (* Check against the target type *)
        begin match eval (Expr.type_of ty) with
        | Type (Var par) when Level.is_arbitrary_string par ->
          (* Synthesize type levels placeholder *)
          Ok (Eq(ty1, e1, e2), Type n, Stack.lappend st sa sb)
        | Type m ->
          (* Check if levels are compatible *)
          if Level.leq n m then
            Ok (Eq(ty1, e1, e2), Type m, Stack.lappend st sa sb)
          else
            Error (Stack.lappend st sa sb, Msg.eq_universe_1 ty1 e1 e2 n m)
        | Meta k ->
          Hashtbl.add Data.meta_store k { Data.solution = Type n};
          Ok (Eq(ty1, e1, e2), Type n, Stack.lappend st sa sb)
        | _ -> Error (Stack.lappend st sa sb, Msg.eq_universe_2 ty1 e1 e2 (eval (Expr.type_of ty)))
        end
      | Error (sl, msg), _  -> Error (sl, Msg.eq_left_mismatch ty1 e1 e2 msg)
      | _, Error (sl, msg) -> Error (sl, Msg.eq_right_mismatch ty1 e1 e2 msg)
      end
    (* The type lives in a metavariable type *)
    | Ok (ty1, Meta n, st) ->
      let elab1 = elaborate env ctx lvl lc sl ty1 vars e1 in
      let elab2 = elaborate env ctx lvl lc sl ty1 vars e2 in
      begin match elab1, elab2 with
      | Ok (e1, _, sa), Ok (e2, _, sb) ->
        (* Check against the target type *)
        begin match (Expr.type_of ty) with
        | Type (Var par) when Level.is_arbitrary_string par ->
          (* Synthesize type levels placeholder *)
          Ok (Eq(ty1, e1, e2), Type (Var par), Stack.lappend st sa sb)
        | Type m ->
          Hashtbl.add Data.meta_store n { Data.solution = Type m};
          Ok (Eq(ty1, e1, e2), Type m, Stack.lappend st sa sb)
        | Meta k ->
          Ok (Eq(ty1, e1, e2), Meta k, Stack.lappend st sa sb)
        | _ -> Error (Stack.lappend st sa sb, Msg.eq_universe_2 ty1 e1 e2 ty)
        end
      | Error msg, _ | _, Error msg -> Error msg
      end
    (* Type is neither a well-specified universe nor a meta *)
    | Ok (ty1, _, st) -> Error (st, Msg.not_a_type ty1)
    | Error (sa, msg) -> Error (sa, Msg.eq_not_a_type ty1 e1 e2 msg)
    end
    
  | Type n ->
    begin match Level.is_declared lvl n with
    | Ok _ ->
      begin match (Expr.type_of ty) with
      | Type m ->
        if Level.leq n m then 
          Ok (Type n, Type m, sl) 
        else if Level.is_arbitrary m then 
          Ok (Type n, Type m, sl)
        else
          Error (sl, Msg.universe_inconsitency n m)
      | Meta _ -> 
        Ok (Type n, Type (Suc n), sl)
      | _ -> Error (sl, Msg.type_mismatch n ty)
      end
    | Error msg -> Error (sl, msg)
    end
  
  | Meta n -> Ok (Meta n, ty, sl)
    
  | Wild n ->
    let solved, used = sl in
    (* If the placeholder has already synthesized replace it *)
    begin match List.find_opt (fun (n', _, _) -> n = n') solved with
    | Some (_, e', _) -> Ok (Global e', ty, sl)
    | None ->
      begin match find n env ctx ty lvl lc sl vars with (* false*)
      | Ok (e', ty') ->
        let sl' = ((n, e', ty') :: solved, used) in
        Ok (Global e', ty, sl')
      | Error _ -> Error (([], []), Msg.synthesis_error ty n ctx)
      end
    end

(* Finds a variable in a context for a given type up to unification *)

and find n env ctx ty lvl lc sl vars =
  let forbidden = snd sl in
  let rec search = function
    | [] -> Error "Can't find match"
    | (id, ty', _) :: ctx' ->
      if List.mem (n, id) forbidden then search ctx'
      else if ty' = ty then 
        Ok (id, ty) (* syntactic equality fast path *)
      else
        (* We ignore their types since they are assumed to be well-typed *)
        let h1 = Placeholder.generate () in
        match unify env ctx lvl lc sl vars (ty, ty', h1) true with
        | Ok uty -> Ok (id, uty)
        | Error _ -> search ctx'
  in
  search ctx

(* Equality reflection on a list of pairs of expressions *)

and eq_reflection_on env ctx lvl lc sl ty vars e1 e2 = function
  | [] ->
    begin match elaborate env ctx lvl lc sl ty vars e2 with
    | Ok (e2, ty, sa) -> Ok (Reflect (e1, e2), ty, sa)
    | Error (sa, msg) -> Error (sa, Msg.reflect_show_goal ctx e2 ty msg)
    end
  | (a, b) :: l ->
    (* Zonks the metavariables on both sides *)
    let a = Placeholder.solve [] a and b = Placeholder.solve [] b in
    let a = eval a and b = eval b in
    (* Explicit substitutions so we can recover the type later on *)
    let ty = Expr.reflsubst 0 b (ESubIn(a, b, ty)) ty in
    let e2 = Expr.reflsubst 0 b (ESubIn(a, b, ty)) e2 in
    eq_reflection_on env ctx lvl lc sl ty vars e1 e2 l

(* Search for proof **in context** that e2 is an equivalence *)
(* To be expanded to global environment *)

and find_equivalence env ctx lvl lc sl vars e ty =
  let rec search_equiv = function
  | [] -> true
  | x :: l ->
    match unify env ctx lvl lc sl vars (e, x, ty) true with
    | Ok _ -> true
    | Error _ -> search_equiv l
  in
  search_equiv (Global.equiv_lookup e ctx)

(* Unifies two expressions at type up to alpha/beta/eta-conversion *)

and unify env ctx lvl lc sl vars x lift =
  match x with
  | e, e', ty ->
    if e = e' then
      Ok e
    else
      match e, e', ty with
      | Meta n1, Meta n2, _ ->
        if n1 <= n2 then Ok (Meta n1) else Ok (Meta n2)

      | e , Meta n, _ | Meta n, e, _ ->
        Hashtbl.add Data.meta_store n { Data.solution = e}; Ok e

      | e , _, Eq(_, _, _) ->
        Ok e

      | Pi (_, ty1, ty2), Pi (_, ty1', ty2'), ty ->
        (* For now we just evaluate, soon we'll only evaluate if they are values *)
        let ty1 = eval ty1 in 
        let ty1' = eval ty1' in
        let u1 = unify env ctx lvl lc sl vars (ty1, ty1', ty) lift in
        begin match u1 with
        | Ok s1 -> 
          let v1 = Expr.init_fresh vars in
          let ty2_open = Expr.fullsubst 0 ty1 s1 (Expr.open_bound (Global v1) ty2) in
          let ty2'_open = Expr.fullsubst 0 ty1' s1 (Expr.open_bound (Global v1) ty2') in
          let ty2_open = eval ty2_open in
          let ty2'_open = eval ty2'_open in
          let u2 = unify env ((v1, s1, true) :: ctx) lvl lc sl (vars+1) (ty2_open, ty2'_open, ty) lift in
          begin match u2 with
          | Ok s2 -> Ok (Pi (v1, s1, Expr.close_bound v1 s2))
          | Error (_, msg) -> Error ((ty2_open, ty2'_open), Msg.unify_pi msg)
          end
        | Error ((e1, e2), msg) -> Error ((e1, e2), Msg.unify_pi msg)
        end

      | Eq (e, e1, e2) , Eq (e', e1', e2'), ty ->
        let e = eval e and e' = eval e' in
        begin match unify env ctx lvl lc sl vars (e, e', ty) lift with
        | Ok s ->
          let e1 = eval e1 and e1' = eval e1' in
          let e2 = eval e2 and e2' = eval e2' in
          let u1 = unify env ctx lvl lc sl vars (e1, e1', s) lift in
          let u2 = unify env ctx lvl lc sl vars (e2, e2', s) lift in
          begin match u1, u2 with
          | Ok s1, Ok s2 ->           
            Ok (Eq (s, s1, s2))
          | Error (sa, msg), _ | _ , Error (sa, msg) -> Error (sa, Msg.unify_eq e e1 e2 e' e1' e2' msg)
          end
        | Error (sa, msg) -> Error (sa, Msg.unify_eq e e1 e2 e' e1' e2' msg)
        end
      
      | Quot (e1, e2), Quot (e1', e2'), ty ->
        let e1 = eval e1 in 
        let e1' = eval e1' in
        begin match unify env ctx lvl lc sl vars (e1, e1', ty) lift with
        | Ok s1 -> 
          let e2 = eval e2 in
          let e2' = eval e2' in
          begin match unify env ctx lvl lc sl (vars+1) (e2, e2', ty) lift with
          | Ok s2 -> Ok (Quot (s1, s2))
          | Error (_, msg) -> Error ((e2, e2'), Msg.unify_quot msg)
          end
        | Error ((e1, e2), msg) -> Error ((e1, e2), Msg.unify_quot msg)
        end
      
      | Mkq (e1, e2), Mkq (e1', e2'), Quot(_, _) ->
        let e1 = eval e1 in 
        let e1' = eval e1' in
        begin match unify env ctx lvl lc sl vars (e1, e1', ty) lift with
        | Ok s1 -> 
          let e2 = eval e2 in
          let e2' = eval e2' in
          begin match unify env ctx lvl lc sl (vars+1) (e2, e2', ty) lift with
          | Ok s2 -> Ok (Mkq (s1, s2))
          | Error (_, msg) -> Error ((e2, e2'), Msg.unify_mkq e1 e2 e1' e2' msg)
          end
        | Error ((e1, e2), msg) -> Error ((e1, e2), Msg.unify_mkq e1 e2 e1' e2' msg)
        end

      | Lam (x, e), Lam (y, e'), Pi(_, ty1 , ty2) ->
        if e = e' then
          Ok (Lam (x, e))
        else if Placeholder.is e' then
          (* Probably want to add to hashtbl *)
          Ok (Lam (x, e))
        else if Placeholder.is e then
          (* Here too *)
          Ok (Lam (x, e'))
        else
          let v1 = Expr.init_fresh vars in
          let ev1 = Expr.open_var 0 (Global v1) e in
          let ev1' = Expr.open_var 0 (Global v1) e' in
          let tyv1 = Expr.open_var 0 (Global v1) ty2 in
          let u = unify env ((v1, ty1, true) :: ctx) lvl lc sl (vars+1) (ev1, ev1', tyv1) lift in
          begin match u with
          | Ok s -> Ok (Lam (v1, s))
          | Error ((e, e'), msg) -> Error ((e, e'), Msg.lam_unify_2 x e y e' msg)
          end
      
      | App (e1, e2), App (e1', e2'), ty ->
        let h1 = Placeholder.generate () in
        let elab2 = elaborate env ctx lvl lc sl h1 vars e2 in
        begin match elab2 with
        | Ok (_, ty2, _) ->
          let u2 = unify env ctx lvl lc sl vars (e2, e2', ty2) lift in
          let v1 = Expr.init_fresh vars in
          let u1 = unify env ctx lvl lc sl (vars+1) (e1, e1', Pi(v1, ty2, Expr.fullsubst 0 e2 (Local 0) ty)) lift in
          begin match u1, u2 with
          | Ok s1, Ok s2 -> Ok (App (s1, s2))
          | Error (ex, msg), _ | _, Error (ex, msg) ->
            (* Check for metavariable application *)
            let head, args = Eval.break_args [] (App (e1, e2)) in
            begin match solve_meta_application args vars (App(e1', e2')) head with
            | Some s -> Ok s
            | None ->
              let head, args = Eval.break_args [] (App (e1', e2')) in
              begin match solve_meta_application args vars (App(e1, e2)) head with
              | Some s -> Ok s
              | None ->
                (* Try again now by evaluating both applications *)
                let app1 = App (e1, e2) in
                let app2 = App (e1', e2') in
                (* TODO: this is not ideal, to avoid re-evaluation, better store values in a hasthtable and look them up *)
                let app1' = eval app1 in
                let app2' = eval app2 in
                if app1 = app1' && app2 = app2' then
                  Error (ex, Msg.app_unify_fallback e1 e2 e1' e2' msg)
                else
                  unify env ctx lvl lc sl (vars+1) (app1', app2', ty) lift
              end
            end
          end
        | Error (_, msg) -> Error ((App (e1, e2), App (e1', e2')), Msg.app_unify_arg e2 h1 msg)
        end
      
      | Reflect (p, e), Reflect (_, e'), _ ->
        let u = unify env ctx lvl lc sl vars (e, e', Meta 0) lift in
        begin match u with
        | Ok e -> Ok (Reflect (p, e))
        | Error msg -> Error msg
        end
      
      | Reflect (p, e), e', _ | e', Reflect (p, e), _->
        let u = unify env ctx lvl lc sl vars (e, e', Meta 0) lift in
        begin match u with
        | Ok e -> Ok (Reflect (p, e))
        | Error msg -> Error msg
        end

      | Explode (p, e), Explode (_, e'), _ ->
        let u = unify env ctx lvl lc sl vars (e, e', Meta 0) lift in
        begin match u with
        | Ok e -> Ok (Explode (p, e))
        | Error msg -> Error msg
        end

      | Type m, Type n, _ ->
        (* Helper compare function *)
        let compare m n = if lift then if Level.leq n m then Ok (Type n) else
            Error ((Type m, Type n), Msg.universe_unify m n)
          else
            Error ((Type m, Type n), Msg.universe_unify_2 m n)
        in
        begin match m, n with
        | Var par, _ when Level.is_arbitrary_string par -> Ok (Type n)
        | _, Var par when Level.is_arbitrary_string par -> Ok (Type m)
        | m, n -> compare m n
        end
      
      | Lam (x, e) , e', _ | e', Lam (x, e), _ ->
        (* Checks for eta-equality *)
        begin match eval e with
        | App (e , Local 0) ->
          if not (Expr.occurs_index 0 0 e) && not (Placeholder.has e) then
            unify env ctx lvl lc sl vars (e, e', ty) lift
          else
            Error ((Lam (x, App (e , Local 0)) , e'), Msg.lam_unify x e e')
        | _ -> Error ((Lam (x, e), e'), Msg.lam_unify x e e')
          end
      
      | ESubIn(e, e2, e3) , ESubIn(e', _, _), ty ->
        let e = eval e and e' = eval e' in
        let u = unify env ctx lvl lc sl vars (e, e', ty) lift in
        begin match u with
        | Ok e -> Ok (ESubIn(e, e2, e3))
        | Error (_, msg) -> Error ((e, e'), Msg.esubin_not_unifiable e e' msg)
        end

      | ESubIn(e, e2, e3) , e', ty | e', ESubIn(e, e2, e3) , ty ->
        let e = eval e and e' = eval e' in
        begin match unify env ctx lvl lc sl vars (e, e', ty) lift with
        | Ok e -> Ok (ESubIn(e, e2, e3))
        | Error _ -> 
          (* Error ((e, e'), Msg.esubin_not_unifiable e e' msg) *)
          begin match unify env ctx lvl lc sl vars (e2, e', ty) lift with
          | Ok e2 -> Ok (ESubIn(e, e2, e3))
          | Error (_, msg) -> Error ((e2, e'), Msg.esubin_not_unifiable (ESubIn(e, e2, e3)) e' msg)
          end
        end
      
      | App (e1, e2), e', _ | e', App (e1, e2), _ ->
        (* Check for metavariable application *)
        let head, args = Eval.break_args [] (App (e1, e2)) in
        begin match solve_meta_application args vars e' head with
        | Some s -> Ok s
        | None -> 
          (* As a last resort we zonk and check their values again *)
          let se' = Placeholder.solve [] e' in
          let se1 = Placeholder.solve [] e1 and se2 = Placeholder.solve [] e2 in
          if e1 = se1 && e2 = se2 && e' = se' then
            Error ((App (e1, e2), e'), Msg.app_mixed_unify e1 e2 e')
          else
            let e = eval (App (se1, se2)) and e' = eval se' in
            begin match unify env ctx lvl lc sl vars (e, e', ty) lift with
            | Ok e -> Ok e
            | Error (_, msg) -> Error ((e, e'), Msg.app_mixed_unify_zonk e e' msg)
            end
        end

      | e , e', _ ->
        (* As a last resort we zonk and check their values again *)
        let e1 = Placeholder.solve [] e in
        let e2 = Placeholder.solve [] e' in
        if e1 = e && e2 = e' then
          (* Stop and return error when there are no metas to zonk in their values *)
          if eval e = eval e' then Ok e else
            Error ((e, e'), Msg.not_syntactically_equal e e')
        else
          let e1 = eval e1 and e2 = eval e2 in
          begin match unify env ctx lvl lc sl vars (e1, e2, ty) lift with
          | Ok e -> Ok e
          | Error (_, msg) -> Error ((e, e'), Msg.zonking_fal msg)
          end