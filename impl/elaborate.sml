structure Elaborate = struct
structure S = Ast
structure T = NamefulType
structure E = NamefulExpr
open S
open T
open E

exception Error of region * string

local

    fun runError m _ =
	OK (m ())
	handle
	Error e => Failed e

    fun elab_i i =
	case i of
	    S.VarI (x, r) =>
	    if x = "true" then
		TrueI r
	    else if x = "false" then
		FalseI r
	    else
		VarI (x, r)
	  | Tint (n, r) =>
            if n = 0 then
                T0 r
            else if n = 1 then
                T1 r
            else
	        Tconst (n, r)
	  | S.Tadd (i1, i2, _) =>
	    Tadd (elab_i i1, elab_i i2)
	  | S.Tmult (i1, i2, _) =>
	    Tmult (elab_i i1, elab_i i2)
	  | S.Tmax (i1, i2, _) =>
	    Tmax (elab_i i1, elab_i i2)
	  | S.Tmin (i1, i2, _) =>
	    Tmin (elab_i i1, elab_i i2)
	  | S.TTI r =>
	    TTI r

    fun elab_p p =
	case p of
	    Pconst (name, r) =>
	    if name = "True" then
		True r
	    else if name = "False" then
		False r
	    else raise Error (r, sprintf "Unrecognized proposition: $" [name])
	  | S.And (p1, p2, _) => And (elab_p p1, elab_p p2)
	  | S.Or (p1, p2, _) => Or (elab_p p1, elab_p p2)
	  | S.Imply (p1, p2, _) => Imply (elab_p p1, elab_p p2)
	  | S.Iff (p1, p2, _) => Iff (elab_p p1, elab_p p2)
	  | S.Eq (i1, i2, _) => Eq (elab_i i1, elab_i i2)
	  | S.TimeLe (i1, i2, _) => TimeLe (elab_i i1, elab_i i2)

    fun elab_b (name, r) =
	if name = "Nat" then
	    (Time, r)
	else if name = "Bool" then
	    (Bool, r)
	else if name = "Unit" then
	    (BSUnit, r)
	else raise Error (r, sprintf "Unrecognized base sort: $" [name])

    fun elab_s s =
	case s of
	    S.Basic b => Basic (elab_b b)
	  | S.Subset (b, name, p, _) => Subset (elab_b b, name, elab_p p)

    fun get_is t =
	case t of 
	    AppTI (t, i, _) =>
	    let val (t, is) = get_is t in
		(t, is @ [i])
	    end
	  | _ => (t, [])

    fun get_ts t =
	case t of 
	    AppTT (t, t2, _) =>
	    let val (t, ts) = get_ts t in
		(t, ts @ [t2])
	    end
	  | _ => (t, [])

    fun is_var_app_ts t = 
	let val (t, ts) = get_ts t in
	    case t of
		S.VarT x => SOME (x, ts)
	      | _ => NONE
	end

    fun elab_t t =
	let 
	    fun make_AppRecur (name, binds, t, is, r) =
		let fun f b =
			case b of
			    Typing (_, _, r) => raise Error (r, "Can't have typing bind in a recursive type")
			  | Kinding (_, r) => raise Error (r, "Can't have kinding bind in a recursive type")
			  | Sorting ((x, _), s, _) => (x, elab_s s)
		in
		    AppRecur (name, map f binds, elab_t t, map elab_i is, r)
		end
	in
	    case t of
		S.VarT (x, r) =>
                if x = "unit" then
                    Unit r
                else if x = "int" then
                    Int r
                else
                    AppV ((x, r), [], [], r)
	      | S.Arrow (t1, d, t2, _) => Arrow (elab_t t1, elab_i d, elab_t t2)
	      | S.Prod (t1, t2, _) => Prod (elab_t t1, elab_t t2)
	      | S.Sum (t1, t2, _) => Sum (elab_t t1, elab_t t2)
	      | S.Quan (quan, binds, t, _) =>
		let fun f (b, t) =
			case b of
			    Typing (_, _, r) => raise Error (r, "Can't have typing bind in a quantification")
			  | Kinding (x, r) =>
			    (case quan of
				 Forall => Uni ((x, r), t)
			       | Exists => raise Error (r, "Doesn't support existential quantification over types"))
			  | Sorting (x, s, _) =>
			    (case quan of
				 Forall => UniI (elab_s s, x, t)
			       | Exists => ExI (elab_s s, x, t))
		in
		    foldr f (elab_t t) binds
		end
	      | S.Recur (name, binds, t, r) => 
		make_AppRecur (name, binds, t, [], r)
	      | S.AppTT (t1, t2, r) =>
		(case is_var_app_ts t1 of
		     SOME (x, ts) => AppV (x, map elab_t (ts @ [t2]), [], r)
		   | NONE => raise Error (r, "Head of type-type application must be a variable"))
	      | S.AppTI (t, i, r) =>
		let val (t, is) = get_is t 
		    val is = is @ [i]
		in
		    case t of
			S.Recur (name, binds, t, _) => make_AppRecur (name, binds, t, is, r)
		      | _ =>
			(case is_var_app_ts t of
			     SOME (x, ts) => AppV (x, map elab_t ts, map elab_i is, r)
			   | NONE => raise Error (r, "The form of type-index application can only be (recursive-type indices) or (variable types indices)"))
		end
	end

    fun elab e =
	case e of
	    S.Var x => Var x
	  | S.Tuple (es, r) =>
	    (case es of
		 [] => TT r
	       | e :: es => foldl (fn (e2, e1) => Pair (e1, elab e2)) (elab e) es)
	  | S.Abs (abs, binds, e, r) =>
	    (case abs of
		 S.Fix => 
		 (case binds of
		      Typing (x, t, _) :: binds => Fix (elab_t t, x, elab (S.Abs (Fn, binds, e, r)))
		    | _ => raise Error (r, "fixpoint must have a typing bind as the first bind"))
	       | Fn =>
		 let fun f (b, e) =
			 case b of
			     Typing (x, t, _) => Abs (elab_t t, x, e)
			   | Kinding x => AbsT (x, e)
			   | Sorting (x, s, _) => AbsI (elab_s s, x, e)
		 in
		     foldr f (elab e) binds
		 end)
	  | S.App (e1, e2, _) =>
	    let 
		fun default () = App (elab e1, elab e2)
	    in
		case e1 of
		    S.Var (x, _) => 
		    if x = "fst" then Fst (elab e2)
		    else if x = "snd" then Snd (elab e2)
		    else if x = "unfold" then Unfold (elab e2)
		    else default ()
		  | S.AppT (S.Var (x, _), t, _) =>
		    if x = "inl" then Inl (elab_t t, elab e2)
		    else if x = "inr" then Inr (elab_t t, elab e2)
		    else if x = "fold" then Fold (elab_t t, elab e2)
		    else default ()
		  | S.AppI (S.AppT (S.Var (x, _), t, _), i, _) =>
		    if x = "pack" then Pack (elab_t t, elab_i i, elab e2)
		    else default ()
		  | _ => default ()
	    end
	  | S.AppT (e, t, _) =>
	    AppT (elab e, elab_t t)
	  | S.AppI (e, i, _) =>
	    AppI (elab e, elab_i i)
	  | S.Case (e, NONE, rules, r) =>
	    (case rules of
		 [(S.Constr ((c1, _), [], (x1, _), _), e1), (S.Constr ((c2, _), [], (x2, _), _), e2)] =>
		 let 
		     val ((x1, e1), (x2, e2)) =
			 if c1 = "inl" andalso c2 = "inr" then
			     ((x1, e1), (x2, e2))
			 else if c2 = "inl" andalso c1 = "inr" then
			     ((x2, e2), (x1, e1))
			 else
			     raise Error (r, "constructor names of sum type must be inl or inr")
		 in
		     SumCase (elab e, x1, elab e1, x2, elab e2)
		 end
	       | _ => raise Error (r, "wrong match patterns for sum type"))
	  | S.Case (e, SOME (t, d), rules, r) =>
	    let 
		fun elab_pn (S.Constr (cname, inames, ename, _)) =
		    Constr (cname, inames, ename)
		fun default () = 
		    Case (elab e, elab_t t, elab_i d, map (fn (pn, e) => (elab_pn pn, elab e)) rules, r)
	    in
		case rules of
		    [(S.Constr ((c, _), [iname], (ename, _), _), e1)] =>
		    if c = "pack" then
			Unpack (elab e, elab_t t, elab_i d, iname, ename, elab e1)
		    else
			default ()
		  | _ => default ()
	    end
	  | S.Ascription (e, t, _) =>
	    Ascription (elab e, elab_t t)
	  | S.AscriptionTime (e, i, _) =>
	    AscriptionTime (elab e, elab_i i)
	  | S.Let (decs, e, r) =>
            Let (map elab_decl decs, elab e, r)
	  | S.Const n => Const n

    and elab_decl decl =
        case decl of
	    S.Val (x, e, _) =>
            Val (x, elab e)
          | S.Datatype (name, tnames, sorts, constrs, r) =>
            let
                fun elab_constr (((cname, _), binds, t1, t2, r) : S.constr_decl) : constr_decl =
                  let fun f bind =
                        case bind of
                            Sorting ((name, _), sort, r) => (name, elab_s sort)
                          | _ => raise Error (r, "Constructors can only have sorting binds")
                      val binds = map f binds
                      val t2_orig = t2
                      val (t2, is) = get_is t2
                      val (t2, ts) = get_ts t2
                      val () = if case t2 of S.VarT (x, _) => x = name | _ => false then
                                   ()
                               else
                                   raise Error (get_region_t t2, "Result type of constructor must be " ^ name)
                      val () = if length ts = length tnames then () else raise Error (get_region_t t2_orig, "Must have type arguments " ^ join " " tnames)
                      fun f (t, tname) =
                        let val targ_mismatch = "This type argument must be " ^ tname in
                            case t of
                                S.VarT (x, r) => if x = tname then () else raise Error (r, targ_mismatch)
                              | _ => raise Error (get_region_t t, targ_mismatch)
                        end
                      val () = app f (zip (ts, tnames))
                  in
                      (cname, (binds, elab_t t1, map elab_i is), r)
                  end
            in
                Datatype (name, tnames, map elab_s sorts, map elab_constr constrs, r)
            end

in
val elaborate = elab
fun elaborate_opt e = runError (fn () => elab e) ()
val elaborate_decl = elab_decl
fun elaborate_decl_opt d = runError (fn () => elab_decl d) ()
end

end
