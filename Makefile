.PHONY: Main.main

default: smlnj

all: smlnj mlton

mlton: main

FILES = \
cont-mlton.sml \
\
enumerator.sml \
util.sml \
string-key.sml \
list-pair-map.sml \
set-util.sml \
map-util.sml \
unique-map.sml \
region.sml \
operators.sml \
\
sexp/sexp.sml \
sexp/sexp.grm \
sexp/sexp.lex \
sexp/parser.sml \
parser/ast.sml \
parser/timl.grm \
parser/timl.lex \
parser/parser.sml \
\
bind.sml \
module-context.sml \
var-uvar.sig \
shift-util.sml \
idx.sig \
idx.sml \
type.sig \
type.sml \
datatype.sml \
pattern.sml \
long-id.sml \
expr.sml \
uvar-expr.sml \
elaborate.sml \
name-resolve.sml \
package.sml \
typecheck-util.sml \
normalize.sml \
collect-var.sml \
collect-uvar.sml \
parallel-subst.sml \
unify.sml \
fresh-uvar.sml \
redundant-exhaust.sml \
uvar-forget.sml \
do-typecheck.sml \
trivial-solver.sml \
post-typecheck.sml \
typecheck.sml \
smt2-printer.sml \
smt-solver.sml \
long-id-map.sml \
bigO-solver.sml \
main.sml \
\
micro-timl/micro-timl.sml \
nouvar-expr.sml \
visitor-util.sml \
unbound.sml \
visitor.sml \
micro-timl/micro-timl-visitor.sml \
micro-timl/micro-timl-ex.sml \
micro-timl/micro-timl-ex-pp.sml \
pattern-ex.sml \
micro-timl/timl-to-micro-timl.sml \
pattern-visitor.sml \
expr-visitor.sml \

main: main.mlb $(FILES)
	mlyacc parser/timl.grm
	mllex parser/timl.lex
	mlyacc sexp/sexp.grm
	mllex sexp/sexp.lex
	mlton $(MLTON_FLAGS) main.mlb

profile:
	mlprof -show-line true -raw true main mlmon.out

smlnj: main.cm
	./format.rb ml-build -Ccontrol.poly-eq-warn=false -Ccompiler-mc.error-non-exhaustive-match=true -Ccompiler-mc.error-non-exhaustive-bind=true main.cm Main.main main-image

clean:
	rm main
	rm main-image*
