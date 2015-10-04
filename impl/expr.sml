structure BasicSorts = struct
(* basic index sort *)
datatype bsort =
	 Time
	 | Bool
	 | BSUnit

fun str_b (s : bsort) : string = 
  case s of
      Time => "Nat"
    | Bool => "Bool"
    | BSUnit => "Unit"
end

signature VAR = sig
    type var
    val str_v : string list -> var -> string
end

signature DEBUG = sig
    type t
    val dummy : t
end

(* types *)
functor TypeFun (structure Var : VAR structure Other : DEBUG) = struct
open Var
open BasicSorts
open Util

type other = Other.t
val dummy = Other.dummy
type id = var * other
type name = string * other

datatype idx =
	 VarI of var * other
	 | T0 of other
	 | T1 of other
	 | Tadd of idx * idx
	 | Tmult of idx * idx
	 | Tmax of idx * idx
	 | Tmin of idx * idx
	 | TrueI of other
	 | FalseI of other
	 | TTI of other
	 | Tconst of int * other

datatype prop =
	 True of other
	 | False of other
	 | And of prop * prop
	 | Or of prop * prop
	 | Imply of prop * prop
	 | Iff of prop * prop
	 | TimeLe of idx * idx
	 | Eq of idx * idx

(* index sort *)
datatype sort =
	 Basic of bsort * other
	 | Subset of (bsort * other) * name * prop
						  
val STime = Basic (Time, dummy)
val SBool = Basic (Bool, dummy)
val SUnit = Basic (BSUnit, dummy)

datatype ty = 
	 Arrow of ty * idx * ty
	 | Prod of ty * ty
	 | Sum of ty * ty
	 | Unit of other
	 | Uni of name * ty
	 | UniI of sort * name * ty
	 | ExI of sort * name * ty
	 (* the kind of Recur is sort => Type, to allow for change of index *)
	 | AppRecur of string * (string * sort) list * ty * idx list * other
	 (* the first operant of App can only be a type variable. The degenerated case of no-arguments is also included *)
	 | AppV of id * ty list * idx list * other
	 | Int of other

fun VarT x = AppV (x, [], [], dummy)
fun AppVar (x, is) = AppV (x, [], is, dummy)

datatype kind = 
	 ArrowK of int * sort list

val Type = ArrowK (0, [])

infix 7 $ val op$ = Tmax
infix 6 %+ val op%+ = Tadd
infix 6 %* val op%* = Tmult
infix 4 %<= val op%<= = TimeLe
infix 3 /\ val op/\ = And
infix 1 --> val op--> = Imply
infix 1 <-> val op<-> = Iff

fun str_i ctx (i : idx) : string = 
  case i of
      VarI (x, _) => str_v ctx x
    | T0 _ => "0"
    | T1 _ => "1"
    | Tadd (d1, d2) => sprintf "($ + $)" [str_i ctx d1, str_i ctx d2]
    | Tmult (d1, d2) => sprintf "($ * $)" [str_i ctx d1, str_i ctx d2]
    | Tmax (d1, d2) => sprintf "(max $ $)" [str_i ctx d1, str_i ctx d2]
    | Tmin (d1, d2) => sprintf "(min $ $)" [str_i ctx d1, str_i ctx d2]
    | TTI _ => "()"
    | TrueI _ => "true"
    | FalseI _ => "false"
    | Tconst (n, _) => str_int n

fun str_p ctx p = 
  case p of
      True _ => "True"
    | False _ => "False"
    | And (p1, p2) => sprintf "($ /\\ $)" [str_p ctx p1, str_p ctx p2]
    | Or (p1, p2) => sprintf "($ \\/ $)" [str_p ctx p1, str_p ctx p2]
    | Imply (p1, p2) => sprintf "($ -> $)" [str_p ctx p1, str_p ctx p2]
    | Iff (p1, p2) => sprintf "($ <-> $)" [str_p ctx p1, str_p ctx p2]
    | TimeLe (d1, d2) => sprintf "($ <= $)" [str_i ctx d1, str_i ctx d2]
    | Eq (i1, i2) => sprintf "($ = $)" [str_i ctx i1, str_i ctx i2]

fun str_s ctx (s : sort) : string = 
  case s of
      Basic (s, _) => str_b s
    | Subset ((s, _), (name, _), p) => sprintf "{ $ :: $ | $ }" [name, str_b s, str_p (name :: ctx) p]

datatype 'a bind = 
         KindingT of string
         | SortingT of string * 'a

fun collect_Uni_UniI t =
  case t of
      Uni ((name, _), t) =>
      let val (names, t) = collect_Uni_UniI t
      in
          (KindingT name :: names, t)
      end
    | UniI (s, (name, _), t) =>
      let val (names, t) = collect_Uni_UniI t
      in
          (SortingT (name, s) :: names, t)
      end
    | _ => ([], t)

fun str_tbinds ctx binds =
  let
      fun f (bind, (acc, (sctx, kctx))) =
        case bind of
            KindingT name => (KindingT name :: acc, (sctx, name :: kctx))
          | SortingT (name, s) => (SortingT (name, str_s sctx s) :: acc, (name :: sctx, kctx))
      val (binds, ctx) = foldl f ([], ctx) binds
      val binds = rev binds
  in
      (binds, ctx)
  end
      
fun str_sortings ctx binds =
  let val (binds, ctx) = str_tbinds (ctx, []) (map SortingT binds)
      fun f bind = case bind of SortingT p => p | _ => raise Impossible "str_tbinds shouldn't return Kinding"
      val binds = map f binds
  in
      (binds, fst ctx)
  end

fun str_t (ctx as (sctx, kctx)) (c : ty) : string =
  let
      fun str_uni ctx t =
        let val (binds, t) = collect_Uni_UniI t 
            val (binds, ctx) = str_tbinds ctx binds
            fun f bind =
              case bind of
                  KindingT name => name
                | SortingT (name, s) => sprintf "{$ : $}" [name, s]
            val binds = map f binds
        in
            sprintf "(forall$, $)" [join_prefix " " binds, str_t ctx t]
        end
  in
      case c of
	  Arrow (c1, d, c2) => sprintf "($ -- $ -> $)" [str_t ctx c1, str_i sctx d, str_t ctx c2]
	| Unit _ => "unit"
	| Prod (t1, t2) => sprintf "($ * $)" [str_t ctx t1, str_t ctx t2]
	| Sum (t1, t2) => sprintf "($ + $)" [str_t ctx t1, str_t ctx t2]
	| Uni _ => str_uni ctx c
	| UniI _ => str_uni ctx c
	| ExI (s, (name, _), t) => sprintf "(exists {$ : $}, $)" [name, str_s sctx s, str_t (name :: sctx, kctx) t]
	| AppRecur (name, ns, t, i, _) => 
	  sprintf "((rec $ $, $) $)" 
		  [name, 
		   join " " (map (fn (name, s) => sprintf "($ :: $)" [name, str_s sctx s]) ns),
		   str_t (rev (map #1 ns) @ sctx, name :: kctx) t,
		   join " " (map (str_i sctx) i)]
	| AppV ((x, _), ts, is, _) => 
	  if null ts andalso null is then
	      str_v kctx x
	  else
	      sprintf "($$$)" [(join "" o map (suffix " ") o map (surround "{" "}") o map (str_i sctx) o rev) is, (join "" o map (suffix " ") o map (str_t ctx) o rev) ts, str_v kctx x]
	| Int _ => "int"
  end

fun str_k ctx (k : kind) : string = 
  case k of
      ArrowK (n, sorts) => sprintf "($$Type)" [if n = 0 then "" else join " * " (repeat n "Type") ^ " => ", if null sorts then "" else join " * " (map (str_s ctx) sorts) ^ " => "]

end

signature TYPE = sig
    type sort
    type idx
    type ty
    val str_i : string list -> idx -> string
    val str_s : string list -> sort -> string
    val str_t : string list * string list -> ty -> string
    val str_sortings : string list -> (string * sort) list -> ((string * string) list * string list)
end

(* expressions *)
functor ExprFun (structure Var : VAR structure Type : TYPE structure Other : DEBUG) = struct
open Var
open Type
open Util

type other = Other.t
type id = var * other
type name = string * other

type constr_core = (string * sort) list * ty * idx list
type constr_decl = string * constr_core * other
type constr = var * string list * constr_core

datatype ptrn =
	 Constr of id * string list * name

datatype expr =
	 Var of var * other
	 | App of expr * expr
	 | Abs of ty * name * expr 
	 (* unit type *)
	 | TT of other
	 (* product type *)
	 | Pair of expr * expr
	 | Fst of expr
	 | Snd of expr
	 (* sum type *)
	 | Inl of ty * expr
	 | Inr of ty * expr
	 | SumCase of expr * string * expr * string * expr
	 (* universal *)
	 | AbsT of name * expr
	 | AppT of expr * ty
	 (* universal index *)
	 | AbsI of sort * name * expr
	 | AppI of expr * idx
	 (* existential index *)
	 | Pack of ty * idx * expr
	 | Unpack of expr * ty * idx * string * string * expr
	 (* recursive type *)
	 | Fold of ty * expr
	 | Unfold of expr
	 | Plus of expr * expr
	 | Const of int * other
	 | AppConstr of id * ty list * idx list * expr
	 | Case of expr * ty * idx * (ptrn * expr) list * other
	 | Never of ty
	 | Let of decl list * expr * other
	 | Fix of ty * name * expr
	 | Ascription of expr * ty
	 | AscriptionTime of expr * idx

     and decl =
         Val of name * expr
	 | Datatype of string * string list * sort list * constr_decl list * other

fun str_pn ctx pn = 
  case pn of
      Constr ((x, _), inames, (ename, _)) => sprintf "$ $ $" [str_v ctx x, join " " inames, ename]

fun ptrn_names pn : string list * string list =
  case pn of
      Constr (_, inames, (ename, _)) => (rev inames, [ename])

fun str_e (ctx as (sctx, kctx, cctx, tctx)) (e : expr) : string =
  let fun add_t name (sctx, kctx, cctx, tctx) = (sctx, kctx, cctx, name :: tctx) 
      val skctx = (sctx, kctx) 
  in
      case e of
	  Var (x, _) => str_v tctx x
	| Abs (t, (name, _), e) => sprintf "(fn ($ : $) => $)" [name, str_t skctx t, str_e (add_t name ctx) e]
	| App (e1, e2) => sprintf "($ $)" [str_e ctx e1, str_e ctx e2]
	| TT _ => "()"
	| Pair (e1, e2) => sprintf "($, $)" [str_e ctx e1, str_e ctx e2]
	| Fst e => sprintf "(fst $)" [str_e ctx e]
	| Snd e => sprintf "(snd $)" [str_e ctx e]
	| Inl (t, e) => sprintf "(inl [$] $)" [str_t skctx t, str_e ctx e]
	| Inr (t, e) => sprintf "(inr [$] $)" [str_t skctx t, str_e ctx e]
	| SumCase (e, name1, e1, name2, e2) => sprintf "(sumcase $ of inl $ => $ | inr $  => $)" [str_e ctx e, name1, str_e (add_t name1 ctx) e1, name2, str_e (add_t name2 ctx) e2]
	| Fold (t, e) => sprintf "(fold [$] $)" [str_t skctx t, str_e ctx e]
	| Unfold e => sprintf "(unfold $)" [str_e ctx e]
	| AbsT ((name, _), e) => sprintf "(fn $ => $)" [name, str_e (sctx, name :: kctx, cctx, tctx) e]
	| AppT (e, t) => sprintf "($ [$])" [str_e ctx e, str_t skctx t]
	| AbsI (s, (name, _), e) => sprintf "(fn $ :: $ => $)" [name, str_s sctx s, str_e (name :: sctx, kctx, cctx, tctx) e]
	| AppI (e, i) => sprintf "($ [$])" [str_e ctx e, str_i sctx i]
	| Pack (t, i, e) => sprintf "(pack $ ($, $))" [str_t skctx t, str_i sctx i, str_e ctx e]
	| Unpack (e1, t, d, iname, ename, e2) => sprintf "unpack $ return $ |> $ as ($, $) in $ end" [str_e ctx e1, str_t skctx t, str_i sctx d, iname, ename, str_e (iname :: sctx, kctx, cctx, ename :: tctx) e2]
	| Fix (t, (name, _), e) => sprintf "(fix ($ : $) => $)" [name, str_t skctx t, str_e (add_t name ctx) e]
	| Let (decls, e, _) => 
          let val (decls, ctx) = str_decls ctx decls
          in
              sprintf "let$ in $ end" [join_prefix " " decls, str_e ctx e]
          end
	| Ascription (e, t) => sprintf "($ : $)" [str_e ctx e, str_t skctx t]
	| AscriptionTime (e, d) => sprintf "($ |> $)" [str_e ctx e, str_i sctx d]
	| Plus (e1, e2) => sprintf "($ + $)" [str_e ctx e1, str_e ctx e2]
	| Const (n, _) => str_int n
	| AppConstr ((x, _), ts, is, e) => sprintf "($$$ $)" [str_v cctx x, (join "" o map (prefix " ") o map (fn t => sprintf "[$]" [str_t skctx t])) ts, (join "" o map (prefix " ") o map (fn i => sprintf "[$]" [str_i sctx i])) is, str_e ctx e]
	| Case (e, t, d, rules, _) => sprintf "(case $ return $ |> $ of $)" [str_e ctx e, str_t skctx t, str_i sctx d, join " | " (map (str_rule ctx) rules)]
	| Never t => sprintf "(never [$])" [str_t skctx t]
  end

and str_decls (ctx as (sctx, kctx, cctx, tctx)) decls =
    let fun f (decl, (acc, ctx)) =
          let val (s, ctx) = str_decl ctx decl
          in
              (s :: acc, ctx)
          end
        val (decls, ctx) = foldl f ([], ctx) decls
        val decls = rev decls
    in
        (decls, ctx)
    end
        
and str_decl (ctx as (sctx, kctx, cctx, tctx)) decl =
    case decl of
        Val ((name, _), e) =>
        (sprintf "val $ = $" [name, str_e ctx e], (sctx, kctx, cctx, name :: tctx))
      | Datatype (name, tnames, sorts, constrs, _) =>
        let val str_tnames = (join_prefix " " o rev) tnames
            fun str_constr_decl (cname, (name_sorts, t, idxs), _) =
              let val (name_sorts, sctx') = str_sortings sctx name_sorts
                  val name_sorts = map (fn (nm, s) => sprintf "$ : $" [nm, s]) name_sorts
              in
                  sprintf "$ of$ $ ->$$ $" [cname, (join_prefix " " o map (surround "{" "}")) name_sorts, str_t (sctx', rev tnames @ name :: kctx) t, (join_prefix " " o map (surround "{" "}" o str_i sctx') o rev) idxs, str_tnames, name]
              end
            val s = sprintf "datatype$$ $ = $" [(join_prefix " " o map (surround "{" "}" o str_s sctx) o rev) sorts, str_tnames, name, join " | " (map str_constr_decl constrs)]
            val cnames = map #1 constrs
            val ctx = (sctx, name :: kctx, rev cnames @ cctx, tctx)
        in
            (s, ctx)
        end

and str_rule (ctx as (sctx, kctx, cctx, tctx)) (pn, e) =
    let val (inames, enames) = ptrn_names pn
	val ctx' = (inames @ sctx, kctx, cctx, enames @ tctx)
    in
	sprintf "$ => $" [str_pn cctx pn, str_e ctx' e]
    end

end
                                                                                          
structure StringVar = struct
type var = string
fun str_v ctx x : string = x
end

structure IntVar = struct
open Util
type var = int
fun str_v ctx x : string =
  (* sprintf "%$" [str_int x] *)
  case nth_error ctx x of
      SOME name => name
    | NONE => "unbound_" ^ str_int x
end

structure R = struct
open Region
type t = region
val dummy = dummy_region
end

structure NamefulType = TypeFun (structure Var = StringVar structure Other = R)
structure NamefulExpr = ExprFun (structure Var = StringVar structure Type = NamefulType structure Other = R)
structure Type = TypeFun (structure Var = IntVar structure Other = R)
structure Expr = ExprFun (structure Var = IntVar structure Type = Type structure Other = R)

