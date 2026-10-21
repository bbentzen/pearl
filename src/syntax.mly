%{
(**
  (c) Copyright 2019 Bruno Bentzen. All rights reserved.
  Released under Apache 2.0 license as described in the file LICENSE.

  Desc: The parser of the program. The file is parsed into the objects 
        of the raw expression type (expressions with named variables) 
        and commands on them (see Ast). Raw expressions are later converted 
        into the core expression type with locally nameless representation.
 **)

open Ast

let rec abs_of_list e = function
  | [] -> e
  | id :: l ->
    RLam(id, abs_of_list e l)

let rec pi_of_list e = function
  | [] -> e
  | (id, ty) :: l ->
    RPi (id, ty, pi_of_list e l)

let rec sigma_of_list e = function
  | [] -> e
  | (id, ty) :: l ->
    RApp (RApp (RId "sigma", ty), RLam(id, sigma_of_list e l))
    (* Ast.RSigma (id, ty, sigma_of_list e l) *)

let rec ids_to_bindings ids ty =
  match ids with
  | [] -> []
  | id :: rest -> (id, ty) :: ids_to_bindings rest ty

let prod_def e1 e2 =
  RApp (RApp (RId "sigma", e1), RLam("v?", e2))

let pair_def e1 e2 =
  RApp(RApp(RApp(RApp (RId "pair", RWild 0), RWild 0), e1), e2)

let iff_def e1 e2 =
  RApp (RApp (RId "sigma", RPi("v?",e1, e2)), RLam("v?", RPi("v?",e2, e1)))

let single_id = function
  | [id] -> id
  | _ -> failwith "Expected exactly one identifier before ':'"

%}

%token <string> ID
%token <string> FILENAME
%token <string> NUMBER
%token EVAL IMPORT IND UNIVERSE DEF THM ABBREV PRINT INFER LBRACE RBRACE
%token TYPE MAX NEXT COLON
%token ABS APP RARROW LRARROW PI
%token LPAREN RPAREN BAR COMMA PROD SIGMA
%token ZERO NAT
%token STAR SUM
%token VOID NEG
%token EQ EQSYM RFL SYMM TRANS REFLECT
%token SLASH LSQBRACK RSQBRACK
%token WILDCARD PLACEHOLDER COLONEQ
%token EOF
%right EQSYM
%right LRARROW
%right PI
%right RARROW
%right SUM PROD
%left TRANS SLASH
%left APP
%nonassoc NEG
%nonassoc LSQBRACK EQ REFLECT EXPLODE
%nonassoc ID LPAREN ABS SIGMA ZERO NAT STAR VOID RFL TYPE PLACEHOLDER WILDCARD
%nonassoc SYMM

%start command
%type <Ast.command> command
%type <Ast.proof> decl
%type <((string list * Ast.rawexpr) * bool) list> ctx
%type <Ast.rawlevel> level
%type <Ast.rawexpr> expr
%type <Ast.rawexpr> app_expr
%type <Ast.rawexpr> head_expr
%type <Ast.rawexpr> atom
%type <string list> ids
%type <string list> vars
%type <((string * Ast.rawexpr) list) * Ast.rawexpr> blocks

%%

command:  
  | decl command                                            {Thm($2, $1)}
  | INFER ctx expr command                                  {Infer($4, $2, $3)}
  | IND ID ctx expr COLONEQ constr command                  {Ind($7, $2, $3, $4, $6)}
  | IMPORT FILENAME command                                 {Import($3, $2)}
  | UNIVERSE ids command                                    {Level($3, $2)}
  | PRINT ID command                                        {Print($3, $2)}
  | EVAL expr command                                       {Eval($3, $2)}
  | EOF                                                     {Eof()}

decl:
  | DEF ID ctx expr COLONEQ expr                            {Prf($2, $3, $4, $6, 0)}
  | THM ID ctx expr COLONEQ expr                            {Prf($2, $3, $4, $6, 1)}
  | ABBREV ID ctx expr COLONEQ expr                         {Prf($2, $3, $4, $6, 2)}

constr: 
  | BAR ID COLON expr                                       {[($2, $4)]}
  | BAR ID COLON expr constr                                {(($2, $4) :: $5)}

ctx: 
  | LPAREN ids COLON expr RPAREN ctx                        {(($2, $4), true) :: $6}
  | LBRACE ids COLON expr RBRACE ctx                        {(($2, $4), false) :: $6}
  | COLON                                                   {([])}

ids:
  | ID                                                      { [$1] }
  | ID ids                                                  { $1 :: $2 }

vars:
  | ID                                                      { [$1] }
  | WILDCARD                                                { ["v?"] }
  | ID vars                                                 { $1 :: $2 }
  | WILDCARD vars                                           { "v?" :: $2 }

blocks:
  | COMMA expr %prec PI                                     { ([], $2) }
  | LPAREN ids COLON expr RPAREN blocks                     { (ids_to_bindings $2 $4 @ fst $6, snd $6) }

level:
  | ID                                                      { RVar ($1) }
  | ZERO                                                    { RNum 0 }
  | NUMBER                                                  { RNum (int_of_string ($1)) }
  | NEXT level                                              { RSuc ($2) }
  | MAX level level                                         { RMax ($2, $3) }
  | LPAREN level RPAREN                                     { $2 }

expr: 
  | app_expr %prec NEG                                      { $1 }
  | expr RARROW expr                                        { RPi("v?", $1, $3) }
  | expr LRARROW expr                                       { iff_def $1 $3 }
  | expr SLASH expr %prec SLASH                             { RQuot($1, $3) }
  | expr PROD expr                                          { prod_def $1 $3 }
  | expr SUM expr                                           { RApp(RApp(RId "sum", $1), $3) }
  | expr EQSYM expr                                         { REq(RWild 0, $1, $3) }
  | expr SYMM                                               { RApp(RId "eq_symm", $1) }
  | expr TRANS expr                                         { RApp(RApp(RId "eq_trans", $1), $3) }

app_expr:
  | head_expr                                               { $1 }
  | app_expr head_expr %prec APP                            { RApp($1,$2) }

head_expr:
  | atom                                                    { $1 }
  | APP head_expr head_expr                                 { RApp($2,$3) }
  | ABS vars COMMA expr %prec PI                            { abs_of_list ($4) ($2) }
  | ABS LPAREN ids COLON expr RPAREN COMMA expr %prec PI    { RLam(single_id $3,$8) }
  | PI blocks                                               { pi_of_list (snd $2) (fst $2) }
  | SIGMA blocks                                            { sigma_of_list (snd $2) (fst $2) }
  | NEG app_expr %prec NEG                                  { RPi("v?", $2, RVoid()) }
  | LSQBRACK expr RSQBRACK expr %prec LSQBRACK              { RMkq($2, $4) }
  | EQ head_expr head_expr head_expr %prec EQ               { REq($2, $3, $4) }
  | REFLECT head_expr head_expr %prec REFLECT               { RReflect($2, $3) }

atom:
  | ID                                                      { RId($1) }
  | LPAREN expr RPAREN                                      { $2 }
  | LPAREN expr COMMA expr RPAREN                           { pair_def $2 $4 }
  | ZERO                                                    { RId("zero") }
  | NAT                                                     { RId("nat") }
  | STAR                                                    { RId("star") }
  | VOID                                                    { RVoid() }
  | RFL                                                     { RRfl() }
  | TYPE level                                              { RType ($2) }
  | PLACEHOLDER NUMBER                                      { RMeta(int_of_string $2) }
  | WILDCARD                                                { RWild 0 }