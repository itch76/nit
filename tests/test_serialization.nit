import serialization
import json_serialization

# Simple class
class A
	auto_serializable
	super Serializable

	var b: Bool
	var c: Char
	var f: Float
	var i: Int
	var s: String
	var n: nullable Int

	init(b: Bool, c: Char, f: Float, i: Int, s: String, n: nullable Int)
	do
		self.b = b
		self.c = c
		self.f = f
		self.i = i
		self.s = s
	end

	redef fun to_s do return "<A: {b} {c} {f} {i} {s} {n != null}>"
end

# Sub-class of A
class B
	auto_serializable
	super A

	var ii: Int
	var ss: String

	init(b: Bool, c: Char, f: Float, i: Int, s: String, n: nullable Int, ii: Int, ss: String)
	do
		super(b, c, f, i, s, n)

		self.ii = ii
		self.ss = ss
	end

	redef fun to_s do return "<B: {super} {ii} {ss}>"
end

# Composed of an A and a B
class C
	auto_serializable
	super Serializable

	var a: A
	var b: B
	var aa: A

	init(a: A, b: B)
	do
		self.a = a
		self.b = b
		self.aa = a
	end

	redef fun to_s do return "<C: {a} {b}>"
end

# Class with cyclic reference
class D
	auto_serializable
	super B

	var d: nullable D = null

	redef fun to_s do return "<D: {super} {d != null}>"
end

var a = new A(true, 'a', 0.1234, 1234, "asdf", null)
var b = new B(false, 'b', 123.123, 2345, "hjkl", 12, 1111, "qwer")
var c = new C(a, b)
var d = new D(false, 'b', 123.123, 2345, "new line ->\n<-", null, 1111, "\t\f\"\r\\/")
d.d = d

for o in new Array[nullable Serializable].with_items(a, b, c, d) do
	var stream = new StringOStream
	var serializer = new JsonSerializer(stream)
	serializer.serialize(o)

	print "# Nit:\n{o}\n"
	print "# Json:\n{stream}\n"
end
