# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# nitcc, a parser and lexer generator for Nit
module nitcc

import nitcc_semantic

# Load the grammar file

if args.is_empty then
	print "usage: nitcc <file> | -"
	exit 1
end
var fi = args.first

var text
if fi != "-" then
	var f = new IFStream.open(fi)
	text = f.read_all
	f.close
else
	text = stdin.read_all
end

# Parse the grammar file

var l = new MyLexer(text)
var ts = l.lex

var p = new MyParser
p.tokens.add_all ts

var node = p.parse

if not node isa NProd then
	print node
	exit 1
	abort
end

var name = node.children.first.as(Ngrammar).children[1].as(Nid).text

print "Grammar {name} (see {name}.gram.dot))"
node.to_dot("{name}.gram.dot")

# Semantic analysis

var v2 = new CollectNameVisitor
v2.start(node)
var gram = v2.gram

if gram.prods.is_empty then
	print "Error: grammar with no production"
	exit(1)
end

# Generate the LR automaton

var lr = gram.lr0

var conflitcs = new ArraySet[Production]
for s in lr.states do for t, a in s.guarded_reduce do if a.length > 1 or s.guarded_shift.has_key(t) then
	for i in a do conflitcs.add(i.alt.prod)
end

if not conflitcs.is_empty then
	print "Error: there is conflicts"
end

if false then loop
if conflitcs.is_empty then break
print "Inline {conflitcs.join(" ")}"
gram.inline(conflitcs)
lr=gram.lr0
end

# Output concrete grammar and LR automaton

var nbalts = 0
for prod in gram.prods do nbalts += prod.alts.length
print "Concrete grammar: {gram.prods.length} productions, {nbalts} alternatives (see {name}.concrete_grammar.txt)"

var pretty = gram.pretty
var f = new OFStream.open("{name}.concrete_grammar.txt")
f.write "// Concrete grammar of {name}\n"
f.write pretty
f.close

print "LR automaton: {lr.states.length} states (see {name}.lr.dot and {name}.lr.txt)"
lr.to_dot("{name}.lr.dot")
pretty = lr.pretty
f = new OFStream.open("{name}.lr.txt")
f.write "// LR automaton of {name}\n"
f.write pretty
f.close

# NFA and DFA

var nfa = v2.nfa
print "NFA automaton: {nfa.states.length} states (see {name}.nfa.dot)"
nfa.to_dot("{name}.nfa.dot")

var dfa = nfa.to_dfa
if dfa.tags.has_key(dfa.start) then
	print "Error: Empty tokens {dfa.tags[dfa.start].join(" ")}"
	exit(1)
end
dfa.solve_token_inclusion
for s, tks in dfa.tags do
	if tks.length <= 1 then continue
	print "Error: Conflicting tokens: {tks.join(" ")}"
	exit(1)
end
print "DFA automaton: {dfa.states.length} states (see {name}.dfa.dot)"
dfa.to_dot("{name}.dfa.dot")

# Generate Nit code

print "Generate {name}_lexer.nit {name}_parser.nit {name}_test_parser.nit"
dfa.gen_to_nit("{name}_lexer.nit", "{name}_parser")
lr.gen_to_nit("{name}_parser.nit")

f = new OFStream.open("{name}_test_parser.nit")
f.write """# Generated by nitcc for the language {{{name}}}
import nitcc_runtime
import {{{name}}}_lexer
import {{{name}}}_parser
class MyTest
	super TestParser
	redef fun name do return \"{{{name}}}\"
	redef fun new_lexer(text) do return new MyLexer(text)
	redef fun new_parser do return new MyParser
end
var t = new MyTest
t.main
"""
f.close
