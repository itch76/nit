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

# Separate compilation of a Nit program
module java_compiler

import rapid_type_analysis
#import transform
import frontend

# Add compiling options
redef class ToolContext
	var opt_output: OptionString = new OptionString("Output file", "-o", "--output")
	var opt_compile_dir: OptionString = new OptionString("Directory used to generate temporary files", "--compile-dir")
	redef init do
		super
		self.option_context.add_option(self.opt_output, self.opt_compile_dir)
	end
end

redef class ModelBuilder
	fun run_java_compiler(mainmodule: MModule, runtime_type_analysis: RapidTypeAnalysis) do
		var time0 = get_time
		self.toolcontext.info("*** GENERATING JAVA ***", 1)

		var compiler = new JavaCompiler(mainmodule, self, runtime_type_analysis)

		# compile java classes used to represents the runtime model of the programm
		compiler.compile_rtmodel

		# compile methods separatly
		compiler.compile_mmethods

		# compile class structures
		compiler.compile_mclasses

		compiler.compile_main_function

		# compile mmodules
		#for mmodule in mainmodule.in_importation.greaters do
				#	compiler.compile_mmodule(mmodule)
				#end

		var time1 = get_time
		self.toolcontext.info("*** END GENERATING JAVA: {time1-time0} ***", 2)
		write_and_make(compiler)
	end

	fun write_and_make(compiler: JavaCompiler)
	do
		var mainmodule = compiler.mainmodule

		var time0 = get_time
		self.toolcontext.info("*** WRITING JAVA ***", 1)

		var compile_dir = toolcontext.opt_compile_dir.value
		if compile_dir == null then compile_dir = ".nit_jcompile"

		compile_dir.mkdir
		var orig_dir=".." # FIXME only works if `compile_dir` is a subdirectory of cw

		var outname = self.toolcontext.opt_output.value
		if outname == null then
			outname = "{mainmodule.jname}"
		end
		var outpath = orig_dir.join_path(outname).simplify_path

		var i = 0
		var jfiles = new List[String]
		for f in compiler.files do
			var filepath = "{compile_dir}/{f.filename}"
			var file = new OFStream.open(filepath)
			for line in f.lines do
				file.write(line)
			end
			file.close
			jfiles.add(f.filename)
			i += 1
		end

		# Generate the manifest
		var manifname = "{mainmodule.jname}.mf"
		var manifpath = "{compile_dir}/{manifname}"
		var maniffile = new OFStream.open(manifpath)
		maniffile.write("Manifest-Version: 1.0\n")
		maniffile.write("Main-Class: {mainmodule.jname}_Main\n")
		maniffile.close

		# Generate the Makefile
		var makename = "{mainmodule.jname}.mk"
		var makepath = "{compile_dir}/{makename}"
		var makefile = new OFStream.open(makepath)

		makefile.write("JC = javac\n\n")
		makefile.write("JAR = jar\n\n")

		makefile.write("all: {outpath}\n\n")
		makefile.write("{mainmodule.jname}_Main.class: {mainmodule.jname}_Main.java\n")
		#makefile.write("\t$(JC) {mainmodule.jname}_Main.java\n\n")
		makefile.write("\t$(JC) {jfiles.join(" ")}\n\n")

		# Compile each generated file
		var ofiles = new List[String]
		for f in jfiles do
			var o = f.strip_extension(".java") + ".class"
			#makefile.write("{o}: {f}\n\t$(JC) -implicit:none {f}\n\n")
			ofiles.add(o)
		end

		# Link edition
		#makefile.write("{outpath}: {ofiles.join(" ")}\n")
		makefile.write("{outpath}: {mainmodule.jname}_Main.class\n")
		makefile.write("\t$(JAR) cfm {outpath}.jar {manifname} {ofiles.join(" ")}\n\n")

		# Clean
		makefile.write("clean:\n\trm {ofiles.join(" ")} 2>/dev/null\n\n")
		makefile.close
		self.toolcontext.info("Generated makefile: {makepath}", 2)

		var time1 = get_time
		self.toolcontext.info("*** END WRITING JAVA: {time1-time0} ***", 2)

		# Execute the Makefile
		time0 = time1
		self.toolcontext.info("*** COMPILING JAVA ***", 1)
		self.toolcontext.info("make -N -C {compile_dir} -f {makename}", 2)

		var res
		if self.toolcontext.verbose_level >= 3 then
			res = sys.system("make -B -C {compile_dir} -f {makename} 2>&1")
		else
			res = sys.system("make -B -C {compile_dir} -f {makename} 2>&1 >/dev/null")
		end
		if res != 0 then
			toolcontext.error(null, "make failed! Error code: {res}.")
		end

		time1 = get_time
		self.toolcontext.info("*** END COMPILING JAVA: {time1-time0} ***", 2)

		# bash script
		var shfile = new OFStream.open(outname)
		shfile.write("#!/bin/bash\n")
		shfile.write("java -jar {outname}.jar \"$@\"\n")
		shfile.close
		sys.system("chmod +x {outname}")
	end
end

class JavaCompiler
	type VISITOR: JavaCompilerVisitor

	var mainmodule: MModule
	var modelbuilder: ModelBuilder
	var runtime_type_analysis: RapidTypeAnalysis

	var files: List[JavaFile] = new List[JavaFile]

	init(mainmodule: MModule, modelbuilder: ModelBuilder, rta: RapidTypeAnalysis) do
		self.mainmodule = mainmodule
		self.modelbuilder = modelbuilder
		self.runtime_type_analysis = rta
	end

	# Initialize a visitor specific for a compiler engine
	fun new_visitor(filename: String): VISITOR do return new JavaCompilerVisitor(self, filename)

	# generate java classes repesenting runtime structures
	fun compile_rtmodel do
		# runtime class
		var v = new_visitor("RTClass.java")
		v.add("import java.util.HashMap;")
		v.add("public abstract class RTClass \{")
		v.add("  public String class_name;")
		v.add("  public HashMap<String, RTMethod> vft = new HashMap<>();")
		v.add("  public HashMap<String, RTClass> supers = new HashMap<>();")
		v.add("  protected RTClass() \{\}")
		v.add("\}")
		# runtime method
		v = new_visitor("RTMethod.java")
		v.add("public abstract class RTMethod \{")
		v.add("  protected RTMethod() \{\}")
        v.add("  public abstract RTVal exec(RTVal[] args);")
		v.add("\}")
		# runtime nit instance
		v = new_visitor("RTVal.java")
		v.add("import java.util.HashMap;")
		v.add("public class RTVal \{")
		v.add("  public RTClass rtclass;")
		v.add("  public HashMap<String, RTVal> attrs = new HashMap<>();")
		v.add("  public Box box;")
		v.add("  public RTVal(RTClass rtclass) \{")
		v.add("    this.rtclass = rtclass;")
		v.add("  \}")
		v.add("  public RTVal(RTClass rtclass, Box box) \{")
		v.add("    this.rtclass = rtclass;")
		v.add("    this.box = box;")
		v.add("  \}")
		v.add("\}")
		# runtime primitive box
		v = new_visitor("Box.java")
		v.add("public class Box \{")
		v.add("  Object value;")
		v.add("  public Box(Object value) \{")
		v.add("    this.value = value;")
		v.add("  \}")
        v.add("  public int int_val() \{ return (int)value; \}")
		v.add("  public boolean boolean_val() \{ return (boolean)value; \}")
		v.add("  public char char_val() \{ return (char)value; \}")
        v.add("  public float float_val() \{ return (float)value; \}")
		v.add("  public String string_val() \{ return (String)value; \}")
		v.add("  public RTVal[] array_val() \{ return (RTVal[])value; \}")
		v.add("\}")
	end

	# generated code for all MClass
	fun compile_mclasses do
		for mclass in mainmodule.model.mclasses do
			compile_mclass(mclass)
		end
	end

	# generate code for a class
	fun compile_mclass(mclass: MClass) do
		var v = new_visitor("{mclass.rt_name}.java")
		v.add("import java.util.HashMap;")
		v.add("public class {mclass.rt_name} extends RTClass \{")
		v.add("  protected static RTClass instance;")
	    v.add("  private {mclass.rt_name}() \{")
		v.add("    this.class_name = \"{mclass.name}\";")
		compile_vft(v, mclass)
		compile_type_table(v, mclass)
		v.add("  \}")
		v.add("  public static RTClass get{mclass.rt_name}() \{")
		v.add("    if(instance == null) \{")
		v.add("      instance = new {mclass.rt_name}();")
		v.add("    \}")
		v.add("    return instance;")
		v.add("  \}")
		v.add("\}")
	end

	# compile vft for a mclass
	fun compile_vft(v: VISITOR, mclass: MClass) do
		# first, collect mproperties
		var mprops = new HashMap[String, MProperty]
		for pclass in mclass.in_hierarchy(mainmodule).greaters do
			for mclassdef in pclass.mclassdefs do
				for mprop in mclassdef.intro_mproperties do
					if not mprop isa MMethod then continue
					if mprops.has_key(mprop.name) then continue
					mprops[mprop.jname] = mprop
				end
			end
		end
		# fill vft with first definitions
		for jname, mprop in mprops do
			var mpropdef = mprop.lookup_first_definition(mainmodule, mclass.intro.bound_mtype)
			var rt_name = mpropdef.rt_name
			v.add("    this.vft.put(\"{jname}\", {rt_name}.get{rt_name}());")
			# fill super next definitions
			var previous = jname
			while mpropdef.has_supercall do
				mpropdef = mpropdef.lookup_next_definition(mainmodule, mclass.intro.bound_mtype)
				rt_name = mpropdef.rt_name
				v.add("    this.vft.put(\"{previous}\", {rt_name}.get{rt_name}()));")
				previous = mpropdef.rt_name
			end
		end
	end

	fun compile_type_table(v: VISITOR, mclass: MClass) do
		for pclass in mclass.in_hierarchy(mainmodule).greaters do
			if pclass == mclass then
				v.add("    supers.put(\"{pclass.jname}\", this);")
			else
				v.add("    supers.put(\"{pclass.jname}\", {pclass.rt_name}.get{pclass.rt_name}());")
			end
		end
	end

	# generate code for all MMethodDef
	fun compile_mmethods do
		for mmodule in mainmodule.in_importation.greaters do
			for mclassdef in mmodule.mclassdefs do
				for mdef in mclassdef.mpropdefs do
					if mdef isa MMethodDef then
						compile_mmethod(mdef)
					end
				end
			end
		end
	end

	# generate code for a method definition
	fun compile_mmethod(mdef: MMethodDef) do
		var v = new_visitor("{mdef.rt_name}.java")
		v.add("import java.util.HashMap;")
		v.add("public class {mdef.rt_name} extends RTMethod \{")
		v.add("  protected static RTMethod instance;")
		v.add("  public static RTMethod get{mdef.rt_name}() \{")
		v.add("    if(instance == null) \{")
		v.add("      instance = new {mdef.rt_name}();")
		v.add("    \}")
		v.add("    return instance;")
		v.add("  \}")
		v.add("  @Override")
		v.add("  public RTVal exec(RTVal[] args) \{")
		if not modelbuilder.mpropdef2npropdef.has_key(mdef) then
			# compile implicit init and auto initialize attributes
			if mdef.mproperty.is_init then
				var i = 1
				v.decl_recv
				for mclassdef in mdef.mclassdef.in_hierarchy.greaters.to_a.reversed do
					for mpropdef in mclassdef.mpropdefs do
						if mpropdef isa MAttributeDef then
							var apropdef = modelbuilder.mpropdef2npropdef[mpropdef]
							if apropdef isa AAttrPropdef then
								if apropdef.is_initialized then
									apropdef.compile_initialized(v)
								else
									apropdef.compile_fromargs(v, i)
									i += 1
								end
							end
						end
					end
				end
			else
				print "NOT YET IMPLEMENTED compile_method for {mdef}({mdef.class_name})"
			end
			v.add("return null;")
		else
			var apropdef = modelbuilder.mpropdef2npropdef[mdef]
			if apropdef isa AAttrPropdef then
				if mdef.mproperty.name.has_suffix("=") then
					apropdef.compile_setter(v)
				else
					apropdef.compile_getter(v)
				end
			else
				apropdef.compile(v)
			end
		end
		v.add("  \}")
		v.add("\}")
	end

	# generate Java main
	fun compile_main_function do
		var v = new_visitor("{mainmodule.jname}_Main.java")
		var sys = v.get_primitive_mclass("Sys")
		v.add("public class {mainmodule.jname}_Main \{")
		v.add("  public static void main(String[] args) \{")
		v.add("    RTVal sys = new RTVal({sys.rt_name}.get{sys.rt_name}());")
		v.add("    sys.rtclass.vft.get(\"main\").exec(new RTVal[]\{sys\});")
		v.add("  \}")
		v.add("\}")
	end
end

class JavaCompilerVisitor
	super Visitor
	type COMPILER: JavaCompiler

	# The associated compiler
	var compiler: JavaCompiler
	var file: JavaFile

	init(compiler: JavaCompiler, filename: String)
	do
		self.compiler = compiler
		self.file = new JavaFile(filename)
		compiler.files.add(file)
	end

	fun add(line: String) do
		file.lines.add("{line}\n")
	end

	fun addn(line: String) do
		file.lines.add(line)
	end

	fun decl_rtval: RTVal do
		var rtval = new RTVal(self)
		add("RTVal {rtval};")
		return rtval
	end

	fun decl_recv: RTVal do
		var rtval = new RTVal.with_name("recv")
		add("RTVal {rtval} = args[0];")
		return rtval
	end

	fun get_recv: RTVal do
		return new RTVal.with_name("recv")
	end


	fun decl_var(variable: Variable): RTVal do
		var rtval = decl_rtval
		var2rtval[variable] = rtval
		return rtval
	end

	fun get_var(variable: Variable): RTVal do
			if not is_var_decl(variable) then
			print "COMPILE ERROR: undeclared {variable}"
			abort
		end
		return var2rtval[variable]
	end

	fun is_var_decl(variable: Variable): Bool do return var2rtval.has_key(variable)
	var var2rtval = new HashMap[Variable, RTVal]

	fun compile_send(mproperty: MProperty, recv: RTVal, args: Array[RTVal]): RTVal do
		var jname = mproperty.jname
		var val = decl_rtval
		var rtargs = [recv]
		rtargs.add_all(args)
		add("{val} = {recv}.rtclass.vft.get(\"{jname}\").exec(new RTVal[]\{{rtargs.join(",")}\});")
		return val
	end

	fun compile_callsite(callsite: CallSite, recv: RTVal, args: Array[RTVal]): RTVal do
		return compile_send(callsite.mproperty, recv, args)
	end

	fun compile_new(mclass: MClass, callsite: CallSite, args: Array[RTVal]): RTVal do
		var recv = decl_rtval
		add("{recv} = new RTVal({mclass.rt_name}.get{mclass.rt_name}());")
		compile_callsite(callsite, recv, args)
		return recv
	end

	fun compile(expr: AExpr) do
		expr.compile(self)
	end

	fun expr(expr: AExpr): RTVal do
		return expr.expr(self).as(not null)
	end

	fun new_var_name: String do
		counter += 1
		return "var{counter}"
	end
	var counter = 0

	fun get_primitive_mclass(name: String): MClass do
		var mclass = compiler.mainmodule.model.get_mclasses_by_name(name)
		if mclass == null then
			print "Fatal Error: no primitive class {name}"
			abort
		else if mclass.length > 1 then
			print "Multiple definition for {name}: {mclass.join(",")}"
			abort
		end
		return mclass.first
	end

	fun get_primitive_mproperty(mtype: MClassType, name: String): MProperty do
		var mprops = compiler.mainmodule.model.get_mproperties_by_name(name)
		for mprop in mprops do
			if mtype.has_mproperty(compiler.mainmodule, mprop) then return mprop
		end
		print "Fatal Error: no primitive method {name} in {mtype}"
		abort
	end

	fun box_rtval(rtval: RTVal, mclass_box: MClass): RTVal do
		var nbox = new RTVal(self)
		add("Box {nbox} = new Box({rtval});")
		var recv = decl_rtval
		add("{recv} = new RTVal({mclass_box.rt_name}.get{mclass_box.rt_name}(), {nbox});")
		return recv
	end

	# box concrete primitive values (Int, Float, Bool, Char) to RTVal
	fun box_value(value: nullable Object): RTVal do
		if value == null then
			var nbox = new RTVal(self)
			add("Box {nbox} = new Box(null);")
			var recv = decl_rtval
			add("{recv} = new RTVal(null, {nbox});")
			return recv
		else if value isa Int then
			var mbox = get_primitive_mclass("Int")
			var nbox = new RTVal(self)
			add("Box {nbox} = new Box({value});")
			var recv = decl_rtval
			add("{recv} = new RTVal({mbox.rt_name}.get{mbox.rt_name}(), {nbox});")
			return recv
		else if value isa Bool then
			var mbox = get_primitive_mclass("Bool")
			var nbox = new RTVal(self)
			add("Box {nbox} = new Box({value});")
			var recv = decl_rtval
			add("{recv} = new RTVal({mbox.rt_name}.get{mbox.rt_name}(), {nbox});")
			return recv
		else if value isa Float then
			var mbox = get_primitive_mclass("Float")
			var nbox = new RTVal(self)
			add("Box {nbox} = new Box({value});")
			var recv = decl_rtval
			add("{recv} = new RTVal({mbox.rt_name}.get{mbox.rt_name}(), {nbox});")
			return recv
		else if value isa Char then
			var mbox = get_primitive_mclass("Char")
			var nbox = new RTVal(self)
			add("Box {nbox} = new Box('{value.to_s.escape_to_c}');")
			var recv = decl_rtval
			add("{recv} = new RTVal({mbox.rt_name}.get{mbox.rt_name}(), {nbox});")
			return recv
		else
			print "NOT YET IMPL. box_value for {value} ({value.class_name})"
			abort
		end
	end
end

class JavaFile
	var filename: String
	var lines: List[String] = new List[String]
	init(filename: String) do 
		self.filename = filename
	end
end

class RTVal
	var rt_name: String

	init(v: JavaCompilerVisitor) do
			self.rt_name = v.new_var_name
	end

	init with_name(name: String) do
		self.rt_name = name
	end

	redef fun to_s do return rt_name
end

redef class MModule
	private fun jname: String do return name.to_cmangle
end

redef class MClass
	private fun jname: String do return name.to_cmangle
	private fun rt_name: String do return "RTClass_{intro.mmodule.jname}_{jname}"
end

redef class MProperty
	private fun jname: String do return name.to_cmangle
end

redef class MPropDef
	private fun rt_name: String do
		return "RTMethod_{mclassdef.mmodule.jname}_{mclassdef.mclass.jname}_{mproperty.jname}"
	end
end

redef class Location
	fun short_location: String do return "{file.filename.escape_to_c}:{line_start}"
end

# nodes compilation

redef class ANode
	type VISITOR: JavaCompilerVisitor
	fun compile(v: VISITOR) do
		print "NOT YET IMPL. ANode::compile for {class_name}"
	end
end

# expressions

redef class AExpr
	fun expr(v: VISITOR): nullable RTVal do
		print "NOT YET IMPL. AEXPR::expr for {class_name}"
		return null
	end
end

redef class AAssertExpr
	redef fun compile(v) do
		var exp = v.expr(n_expr)
		v.add("if(!{exp}.box.boolean_val()) \{")
		if n_else != null then v.compile(n_else.as(not null))
		v.add("  System.out.println(\"Runtime error: Assert failed ({location.short_location})\");")
		v.add("  System.exit(1);")
		v.add("  return null;")
		v.add("\}")
	end
end

redef class AAbortExpr
	redef fun compile(v) do
		v.add("System.out.println(\"Runtime error: Aborted ({location.short_location})\");")
		v.add("System.exit(1);")
		v.add("return null;")
	end
end

redef class AAndExpr
	redef fun expr(v) do
		var val = new RTVal(v)
		var exp1 = v.expr(n_expr)
		var exp2 = v.expr(n_expr2)
		v.add("boolean {val} = ({exp1}.box.boolean_val() && {exp2}.box.boolean_val());")
		var mclass = v.get_primitive_mclass("Bool")
		return v.box_rtval(val, mclass)
	end
end

redef class AArrayExpr
	redef fun expr(v) do
		var size = n_exprs.n_exprs.length
		# init NativeArray
		var native = new RTVal(v)
		v.add("RTVal[] {native} = new RTVal[{size}];")
		var i = 0
		for n_expr in n_exprs.n_exprs do
			var exp = v.expr(n_expr)
			v.add("{native}[{i}] = {exp};")
			i += 1
		end
		var mnative = v.get_primitive_mclass("NativeArray")
		var nbox = v.box_rtval(native, mnative)
		# init Array
		var marray = v.get_primitive_mclass("Array")
		var recv = v.decl_rtval
		v.add("{recv} = new RTVal({marray.rt_name}.get{marray.rt_name}());")
		# call init.with_native
		var rtsize = v.box_value(size)
		var args = [recv, nbox, rtsize]
		v.add("{recv}.rtclass.vft.get(\"with_native\").exec(new RTVal[]\{{args.join(",")}\});")
		return recv
	end
end

redef class AAsNotnullExpr
	redef fun expr(v) do
		var exp = v.expr(n_expr)
		v.add("if ({exp}.rtclass == null) \{")
		v.add("  System.out.println(\"Runtime error: Cast failed ({location.short_location})\");")
		v.add("  System.exit(1);")
		v.add("  return null;")
		v.add("\}")
		return exp
	end
end

redef class AAttrExpr
	redef fun expr(v) do
		var recv = v.get_recv
		var val = v.decl_rtval
		v.add("{val} = {recv}.attrs.get(\"{mproperty.jname}\");")
		return val
	end
end

redef class AAttrAssignExpr
	redef fun compile(v) do
		var recv = v.expr(n_expr)
		var val = v.expr(n_value)
		v.add("{recv}.attrs.put(\"{mproperty.jname}\", {val});")
	end
end

redef class AAttrPropdef
	fun is_initialized: Bool do return n_expr != null

	fun compile_initialized(v: VISITOR) do
		var recv = v.get_recv
		var val = v.expr(n_expr.as(not null))
		v.add("{recv}.attrs.put(\"{mpropdef.mproperty.jname}\", {val});")
	end

	fun compile_fromargs(v: VISITOR, index: Int) do
		var recv = v.get_recv
		v.add("{recv}.attrs.put(\"{mpropdef.mproperty.jname}\", args[{index}]);")
	end

	fun compile_setter(v: VISITOR) do
		var recv = v.decl_recv
		var val = v.decl_rtval
		v.add("{val} = args[1];")
		v.add("{recv}.attrs.put(\"{mpropdef.mproperty.jname}\", {val});")
		v.add("return null;")
	end

	fun compile_getter(v: VISITOR) do
		var recv = v.decl_recv
		var res = v.decl_rtval
		v.add("{res} = {recv}.attrs.get(\"{mpropdef.mproperty.jname}\");")
		v.add("return {res};")
	end
end

redef class AAttrReassignExpr
	redef fun compile(v) do
		v.add("//LAAAAAA")
		var callsite = reassign_callsite.as(not null)
		var recv = v.get_recv
		var val = v.expr(n_value)
		var old = v.decl_rtval
		v.add("{old} = {recv}.attrs.get(\"{mproperty.jname}\");")
		var rtnew = v.compile_callsite(callsite, old, [val])
		v.add("{recv}.attrs.put(\"{mproperty.jname}\", {rtnew});")
		v.add("// HEEEEEERE")
	end
end


redef class ABinopExpr
	redef fun expr(v) do
		var callsite = self.callsite.as(not null)
		var recv = v.expr(n_expr)
		var args = [v.expr(n_expr2)]
		return v.compile_callsite(callsite, recv, args)
	end
end

redef class ABlockExpr
	redef fun compile(v) do for exp in n_expr do v.compile(exp)
end

redef class ABraExpr
	redef fun expr(v) do
		var callsite = self.callsite.as(not null)
		var recv = v.expr(n_expr)
		var args = new Array[RTVal]
		for raw_arg in raw_arguments do args.add(v.expr(raw_arg))
		return v.compile_callsite(callsite, recv, args)
	end
end

redef class ABraAssignExpr
	redef fun compile(v) do
		var callsite = self.callsite.as(not null)
		var recv = v.expr(n_expr)
		var args = new Array[RTVal]
		for raw_arg in raw_arguments do args.add(v.expr(raw_arg))
		args.add(v.expr(n_value))
		v.compile_callsite(callsite, recv, args)
	end
end

redef class ADeferredMethPropdef
	redef fun compile(v) do
		v.add("System.out.println(\"Runtime error: Abstract method `{mpropdef.mproperty.name}` called on `{mpropdef.mclassdef.mclass.name}` ({location.short_location})\");")
		v.add("return null;")
	end
end

redef class ACallExpr
	redef fun expr(v) do
		var callsite = self.callsite.as(not null)
		var recv = v.expr(n_expr)
		var args = new Array[RTVal]
		for raw_arg in raw_arguments do args.add(v.expr(raw_arg))
		return v.compile_callsite(callsite, recv, args)
	end

	redef fun compile(v) do expr(v)
end

redef class ACallAssignExpr
	redef fun compile(v) do
		var callsite = self.callsite.as(not null)
		var recv = v.expr(n_expr)
		var args = [v.expr(n_value)]
		v.compile_callsite(callsite, recv, args)
	end
end

redef class ACharExpr
	redef fun expr(v) do return v.box_value(value.as(not null))
end

redef class AConcreteMethPropdef
	redef fun compile(v) do
		if n_block != null then
			var recv = v.decl_recv
			if n_signature != null then
				var i = 1
				for param in n_signature.n_params do
					var val = v.decl_var(param.variable.as(not null))
					v.add("{val} = args[{i}];")
					i += 1
				end
			end
			v.compile(n_block.as(not null))
		end
		if mpropdef.msignature.return_mtype == null then
			v.add("return null;")
		end
	end
end

redef class AEqExpr
	redef fun expr(v) do
			#print 
		return super
	end
end

redef class AExternMethPropdef
	redef fun compile(v) do
		print "NOT YET IMPL. AExternMethPropdef::compile"
		v.add("return null;")
	end
end

redef class AFalseExpr
	redef fun expr(v) do return v.box_value(false)
end

redef class AForExpr
	redef fun compile(v) do
		var mtype = n_expr.mtype
		if not mtype isa MClassType then
			print "Fatal error: expr does not return a mclass_type ({location})"
			abort
		end
		var recv = v.expr(n_expr)

		if variables.length == 1 then
			var get_it = v.get_primitive_mproperty(mtype.mclass.intro.bound_mtype, "iterator")
			var mit = v.get_primitive_mclass("Iterator")
			var mit_isok = v.get_primitive_mproperty(mit.intro.bound_mtype, "is_ok")
			var mit_item = v.get_primitive_mproperty(mit.intro.bound_mtype, "item")
			var mit_next = v.get_primitive_mproperty(mit.intro.bound_mtype, "next")
			# var it = recv.iterator()
			var it = v.compile_send(get_it, recv, new Array[RTVal])
			# var is_ok = it.is_ok
			var it_isok = v.compile_send(mit_isok, it, new Array[RTVal])
			# while(is_ok) do
			v.add("while({it_isok}.box.boolean_val()) \{")
			#   var i = it.item
			var i = v.decl_var(variables.first)
			var item = v.compile_send(mit_item, it, new Array[RTVal])
			v.add("{i} = {item};")
			#   ...
			if n_block != null then v.compile(n_block.as(not null))
			#   it.next
			v.compile_send(mit_next, it, new Array[RTVal])
			#   is_ok = it.is_ok
			var next_ok = v.compile_send(mit_isok, it, new Array[RTVal])
			v.add("{it_isok} = {next_ok};")
			# end
			v.add("\}")
		else
			var get_it = v.get_primitive_mproperty(mtype.mclass.intro.bound_mtype, "iterator")
			var mit = v.get_primitive_mclass("MapIterator")
			var mit_isok = v.get_primitive_mproperty(mit.intro.bound_mtype, "is_ok")
			var mit_key = v.get_primitive_mproperty(mit.intro.bound_mtype, "key")
			var mit_item = v.get_primitive_mproperty(mit.intro.bound_mtype, "item")
			var mit_next = v.get_primitive_mproperty(mit.intro.bound_mtype, "next")
			# var it = recv.iterator()
			var it = v.compile_send(get_it, recv, new Array[RTVal])
			# var is_ok = it.is_ok
			var it_isok = v.compile_send(mit_isok, it, new Array[RTVal])
			# while(is_ok) do
			v.add("while({it_isok}.box.boolean_val()) \{")
			#   var i = it.item
			var i = v.decl_var(variables.first)
			var item = v.compile_send(mit_item, it, new Array[RTVal])
			v.add("{i} = {item};")
			#   var j = it.key
			var j = v.decl_var(variables[1])
			var key = v.compile_send(mit_key, it, new Array[RTVal])
			v.add("{j} = {key};")
			#   ...
			if n_block != null then v.compile(n_block.as(not null))
			#   it.next
			v.compile_send(mit_next, it, new Array[RTVal])
			#   is_ok = it.is_ok
			var next_ok = v.compile_send(mit_isok, it, new Array[RTVal])
			v.add("{it_isok} = {next_ok};")
			# end
			v.add("\}")
		end
	end
end

redef class AIfExpr
	redef fun compile(v) do
		var val = v.expr(n_expr)
		v.add("if ({val}.box.boolean_val()) \{")
		if n_then != null then
			v.compile(n_then.as(not null))
		end
		if n_else != null then
			v.add("\} else \{")
			v.compile(n_else.as(not null))
		end
		v.add("\}")
	end
end

redef class AImplicitSelfExpr
	redef fun expr(v) do return v.get_recv
end

redef class AIntExpr
	redef fun expr(v) do return v.box_value(value.as(not null))
end

redef class AInternMethPropdef
	redef fun compile(v) do
		var mclass = mpropdef.mclassdef.mclass
		var mprop = mpropdef.mproperty
		var recv = v.decl_rtval
		v.add("{recv} = args[0];")

		# primitive mapping to java
		if mclass.name == "Object" then # object
			if mprop.name == "object_id" then # object_id use java hashcode
				var box_mclass = v.get_primitive_mclass("Int")
				var id = new RTVal(v)
				v.add("int {id} = {recv}.hashCode();")
				var box = v.box_rtval(id, box_mclass)
				v.add("return {box};")
				return
			else if mprop.name == "is_same_instance" then
				var box_mclass = v.get_primitive_mclass("Bool")
				var exp = v.decl_rtval
				v.add("{exp} = args[1];")
				var res = new RTVal(v)
				v.add("boolean {res} = {recv}.hashCode() == {exp}.hashCode();")
				var box = v.box_rtval(res, box_mclass)
				v.add("return {box};")
				return
			end
		else if mclass.name == "Bool" then # Bool primitive
			if mprop.name == "==" then
				compile_bool_op(v, recv, "boolean", "==")
			else if mprop.name == "!=" then
				compile_bool_op(v, recv, "boolean", "!=")
			else if mprop.name == "object_id" then
				var box_int = v.get_primitive_mclass("Int")
				var id = new RTVal(v)
				v.add("int {id} = {recv}.box.boolean_val() ? 1 : 0;")
				var box = v.box_rtval(id, box_int)
				v.add("return {box};")
			else if mprop.name == "output" then
				v.add("System.out.println({recv}.box.boolean_val());")
				v.add("return null;")
			end
			return
		else if mclass.name == "Int" then # Int primnitive
			var box_int = v.get_primitive_mclass("Int")
			if mprop.name == "==" then
				compile_bool_op(v, recv, "int", "==")
			else if mprop.name == "!=" then
				compile_bool_op(v, recv, "int", "!=")
			else if mprop.name == "<=" then
				compile_bool_op(v, recv, "int", "<=")
			else if mprop.name == "<" then
				compile_bool_op(v, recv, "int", "<")
			else if mprop.name == ">=" then
				compile_bool_op(v, recv, "int", ">=")
			else if mprop.name == ">" then
				compile_bool_op(v, recv, "int", ">")
			else if mprop.name == "+" then
				compile_int_op(v, recv, "+")
			else if mprop.name == "-" then
				compile_int_op(v, recv, "-")
			else if mprop.name == "*" then
				compile_int_op(v, recv, "*")
			else if mprop.name == "/" then
				compile_int_op(v, recv, "/")
			else if mprop.name == "%" then
				compile_int_op(v, recv, "%")
			else if mprop.name == "lshift" then
				compile_int_op(v, recv, "<<")
			else if mprop.name == "rshift" then
				compile_int_op(v, recv, ">>")
			else if mprop.name == "unary -" then
				var res = new RTVal(v)
				v.add("int {res} = -({recv}.box.int_val());")
				var box = v.box_rtval(res, box_int)
				v.add("return {box};")
			else if mprop.name == "succ" then
				var res = new RTVal(v)
				v.add("int {res} = ({recv}.box.int_val() + 1);")
				var box = v.box_rtval(res, box_int)
				v.add("return {box};")
			else if mprop.name == "prec" then
				var res = new RTVal(v)
				v.add("int {res} = ({recv}.box.int_val() - 1);")
				var box = v.box_rtval(res, box_int)
				v.add("return {box};")
			else if mprop.name == "to_f" then
				var box_f = v.get_primitive_mclass("Float")
				var res = new RTVal(v)
				v.add("float {res} = (float){recv}.box.int_val();")
				var box = v.box_rtval(res, box_f)
				v.add("return {box};")
			else if mprop.name == "ascii" then
				var box_c = v.get_primitive_mclass("Char")
				var res = new RTVal(v)
				v.add("char {res} = (char){recv}.box.int_val();")
				var box = v.box_rtval(res, box_c)
				v.add("return {box};")
			else if mprop.name == "object_id" then
				var id = new RTVal(v)
				v.add("int {id} = {recv}.box.int_val();")
				var box = v.box_rtval(id, box_int)
				v.add("return {box};")
			else if mprop.name == "output" then
				v.add("System.out.println({recv}.box.int_val());")
				v.add("return null;")
			end
			return
		else if mclass.name == "Float" then # Float primnitive
			var box_float = v.get_primitive_mclass("Float")
			if mprop.name == "<=" then
				compile_bool_op(v, recv, "float", "<=")
			else if mprop.name == "<" then
				compile_bool_op(v, recv, "float", "<")
			else if mprop.name == ">=" then
				compile_bool_op(v, recv, "float", ">=")
			else if mprop.name == ">" then
				compile_bool_op(v, recv, "float", ">")
			else if mprop.name == "+" then
				compile_float_op(v, recv, "+")
			else if mprop.name == "-" then
				compile_float_op(v, recv, "-")
			else if mprop.name == "*" then
				compile_float_op(v, recv, "*")
			else if mprop.name == "/" then
				compile_float_op(v, recv, "/")
			else if mprop.name == "unary -" then
				var res = new RTVal(v)
				v.add("float {res} = -({recv}.box.float_val());")
				var box = v.box_rtval(res, box_float)
				v.add("return {box};")
			else if mprop.name == "to_i" then
				var box_i = v.get_primitive_mclass("Int")
				var res = new RTVal(v)
				v.add("int {res} = (int){recv}.box.float_val();")
				var box = v.box_rtval(res, box_i)
				v.add("return {box};")
			else if mprop.name == "object_id" then
				var box_int = v.get_primitive_mclass("Int")
				var id = new RTVal(v)
				v.add("int {id} = {recv}.box.int_val();")
				var box = v.box_rtval(id, box_int)
				v.add("return {box};")
			else if mprop.name == "output" then
				v.add("System.out.println({recv}.box.float_val());")
				v.add("return null;")
			end
			return
		else if mclass.name == "Char" then # Char primnitive
			var box_char = v.get_primitive_mclass("Char")
			if mprop.name == "==" then
				compile_bool_op(v, recv, "char", "==")
			else if mprop.name == "!=" then
				compile_bool_op(v, recv, "char", "!=")
			else if mprop.name == "<=" then
				compile_bool_op(v, recv, "char", "<=")
			else if mprop.name == "<" then
				compile_bool_op(v, recv, "char", "<")
			else if mprop.name == ">=" then
				compile_bool_op(v, recv, "char", ">=")
			else if mprop.name == ">" then
				compile_bool_op(v, recv, "char", ">")
			else if mprop.name == "+" then
				compile_char_op(v, recv, "+")
			else if mprop.name == "-" then
				compile_char_op(v, recv, "-")
			else if mprop.name == "succ" then
				var res = new RTVal(v)
				v.add("int {res} = ({recv}.box.char_val() + 1);")
				var box = v.box_rtval(res, box_char)
				v.add("return {box};")
			else if mprop.name == "prec" then
				var res = new RTVal(v)
				v.add("int {res} = ({recv}.box.char_val() - 1);")
				var box = v.box_rtval(res, box_char)
				v.add("return {box};")
			else if mprop.name == "ascii" then
				var box_i = v.get_primitive_mclass("Int")
				var res = new RTVal(v)
				v.add("int {res} = (int){recv}.box.char_val();")
				var box = v.box_rtval(res, box_i)
				v.add("return {box};")
			else if mprop.name == "object_id" then
				var box_int = v.get_primitive_mclass("Int")
				var id = new RTVal(v)
				v.add("int {id} = {recv}.box.char_val();")
				var box = v.box_rtval(id, box_int)
				v.add("return {box};")
			else if mprop.name == "output" then
				v.add("System.out.print({recv}.box.char_val());")
				v.add("return null;")
			end
			return
		else if mclass.name == "NativeArray" then
			if mprop.name == "[]" then
				v.add("return {recv}.box.array_val()[args[1].box.int_val()];")
			else if mprop.name == "[]=" then
				v.add("{recv}.box.array_val()[args[1].box.int_val()] = args[2];")
				v.add("return null;")
			else if mprop.name == "copy_to" then
				var i = new RTVal(v)
				var dest = v.decl_rtval
				v.add("{dest} = args[1];")
				v.add("for(int {i} = 0; {i} < {recv}.box.array_val().length; {i}++) \{")
				v.add("  {dest}.box.array_val()[{i}] = {recv}.box.array_val()[{i}];")
				v.add("\}")
				v.add("return null;")
			end
			return
		else if mclass.name == "ArrayCapable" then
			if mprop.name == "calloc_array" then
				var box_arr = v.get_primitive_mclass("NativeArray")
				var arr = new RTVal(v)
				v.add("RTVal[] {arr} = new RTVal[args[1].box.int_val()];")
				var box = v.box_rtval(arr, box_arr)
				v.add("return {box};")
				return
			end
		end
		print "AInternMethPropdef::compile for {mpropdef}"
		#TODO missing primitives
		v.add("return null;")
	end

	private fun compile_bool_op(v: JavaCompilerVisitor, recv: RTVal, jtype: String, op: String) do
		var box_bool = v.get_primitive_mclass("Bool")
		var exp = v.decl_rtval
		v.add("{exp} = args[1];")
		var res = new RTVal(v)
		if op == "==" or op == "!=" then
			v.add("boolean {res} = {recv}.box.value {op} {exp}.box.value;")
		else
			v.addn("boolean {res} = ({recv}.box.value != null && {exp}.box.value != null)")
			v.add(" && ({recv}.box.{jtype}_val() {op} {exp}.box.{jtype}_val());")
		end
		var box = v.box_rtval(res, box_bool)
		v.add("return {box};")
	end

	private fun compile_int_op(v: JavaCompilerVisitor, recv: RTVal, op: String) do
		var box_int = v.get_primitive_mclass("Int")
		var exp = v.decl_rtval
		v.add("{exp} = args[1];")
		var res = new RTVal(v)
		v.add("int {res} = ({recv}.box.int_val() {op} {exp}.box.int_val());")
		var box = v.box_rtval(res, box_int)
		v.add("return {box};")
	end

	private fun compile_float_op(v: JavaCompilerVisitor, recv: RTVal, op: String) do
		var box_float = v.get_primitive_mclass("Float")
		var exp = v.decl_rtval
		v.add("{exp} = args[1];")
		var res = new RTVal(v)
		v.add("float {res} = ({recv}.box.float_val() {op} {exp}.box.float_val());")
		var box = v.box_rtval(res, box_float)
		v.add("return {box};")
	end

	private fun compile_char_op(v: JavaCompilerVisitor, recv: RTVal, op: String) do
		var box_char = v.get_primitive_mclass("Char")
		var exp = v.decl_rtval
		v.add("{exp} = args[1];")
		var res = new RTVal(v)
		v.add("char {res} = (char)({recv}.box.char_val() {op} {exp}.box.char_val());")
		var box = v.box_rtval(res, box_char)
		v.add("return {box};")
	end
end

redef class AIsaExpr
	redef fun expr(v) do
		var bool_box = v.get_primitive_mclass("Bool")
		var recv = v.expr(n_expr)
		var mclass = n_type.mtype.as(MClassType).mclass
		var res = new RTVal(v)
		v.add("boolean {res} = {recv}.rtclass.supers.get(\"{mclass.jname}\") == {mclass.rt_name}.get{mclass.rt_name}();")
		return v.box_rtval(res, bool_box)
	end
end

redef class ALoopExpr
	redef fun compile(v) do
		v.add("while(true) \{")
		if not n_block == null then v.compile(n_block.as(not null))
		v.add("\}")
	end
end

redef class ANotExpr
	redef fun expr(v) do
		var exp = v.expr(n_expr)
		var val = new RTVal(v)
		v.add("boolean {val} = !{exp}.box.boolean_val();")
		var mclass = v.get_primitive_mclass("Bool")
		return v.box_rtval(val, mclass)
	end
end

redef class ANeExpr
	redef fun expr(v) do
		var mclass = v.get_primitive_mclass("Bool")
		var exp1 = v.expr(n_expr)
		var exp2 = v.expr(n_expr2)
		if n_expr2.mtype isa MNullType then
			var res = new RTVal(v)
			v.add("boolean {res} = {exp1}.rtclass != null;")
			return v.box_rtval(res, mclass)
		else if n_expr.mtype isa MNullableType then
			var res = v.decl_rtval
			v.add("if({exp1}.rtclass == null && {exp2}.rtclass != null) \{")
			var box = v.box_value(true)
			v.add("  {res} = {box};")
			v.add("\} else \{")
			var superres = super
			v.add("  {res} = {superres};")
			v.add("\}")
			return res
		end
		return super
	end
end

redef class ANewExpr
	redef fun expr(v) do
		var mclass = n_type.mtype.as(MClassType).mclass
		var callsite = self.callsite.as(not null)
		var args = new Array[RTVal]
		for raw_arg in n_args.n_exprs do args.add(v.expr(raw_arg))
		return v.compile_new(mclass, callsite, args)
	end
end

redef class ANullExpr
	redef fun expr(v) do return v.box_value(null)
end

redef class AOrExpr
	redef fun expr(v) do
		var val = new RTVal(v)
		var exp1 = v.expr(n_expr)
		var exp2 = v.expr(n_expr2)
		v.add("boolean {val} = ({exp1}.box.boolean_val() || {exp2}.box.boolean_val());")
		var mclass = v.get_primitive_mclass("Bool")
		return v.box_rtval(val, mclass)
	end
end

redef class AParExpr
	redef fun expr(v) do
		var val = v.decl_rtval
		var exp = v.expr(n_expr)
		v.add("{val} = {exp};")
		return val
	end
end

redef class AReturnExpr
	redef fun compile(v) do
		if n_expr != null then
			var expr = v.expr(n_expr.as(not null))
			v.add("return {expr};")
		end
	end
end

redef class ASelfExpr
	redef fun expr(v) do return v.get_recv
end

redef class AStringExpr
	redef fun expr(v) do
		# init NativeString
		var string = new RTVal(v)
		v.add("String {string} = \"{value.to_s}\";")
		var mnative = v.get_primitive_mclass("NativeArray")
		var nbox = v.box_rtval(string, mnative)
		# init String
		var mstring = v.get_primitive_mclass("String")
		var recv = v.decl_rtval
		v.add("{recv} = new RTVal({mstring.rt_name}.get{mstring.rt_name}());")
		# call init.with_infos
		var rtlen = v.box_value(value.length)
		var rtfrom = v.box_value(0)
		var rtto = v.box_value(value.length - 1)
		var args = [recv, nbox, rtlen, rtfrom, rtto]
		v.add("{recv}.rtclass.vft.get(\"with_infos\").exec(new RTVal[]\{{args.join(",")}\});")
		return recv
	end
end

redef class ATrueExpr
	redef fun expr(v) do return v.box_value(true)
end

redef class AUminusExpr
	redef fun expr(v) do
		var callsite = self.callsite.as(not null)
		var recv = v.expr(n_expr)
		var args = new Array[RTVal]
		return v.compile_callsite(callsite, recv, args)
	end
end

redef class AVarExpr
	redef fun expr(v) do
		return v.get_var(variable.as(not null))
	end
end

redef class AVardeclExpr
	redef fun compile(v) do
		var val = v.decl_var(variable.as(not null))
		if n_expr != null then
			var nval = v.expr(n_expr.as(not null))
			v.addn(val.rt_name)
			v.addn(" = ")
			v.addn(nval.rt_name)
			v.add(";")
		end
	end
end

redef class AVarAssignExpr
	redef fun compile(v) do
		var val = v.get_var(variable.as(not null))
		var expr = v.expr(n_value)
		v.add("{val} = {expr};")
	end
end

redef class AVarReassignExpr
	redef fun compile(v) do
		var callsite = self.reassign_callsite.as(not null)
		var recv = v.get_var(variable.as(not null))
		var args = [v.expr(n_value)]
		v.compile_callsite(callsite, recv, args)
	end
end

redef class AWhileExpr
	redef fun compile(v) do
		var exp = v.expr(n_expr)
		v.add("while({exp}.box.boolean_val()) \{")
		if n_block != null then v.compile(n_block.as(not null))
		v.add("\}")
	end
end

