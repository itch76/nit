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
		# link eidtion (compile class structures and constructors)
		compiler.compile_mclasses
		# compile the main function that will exec Sys.main
		compiler.compile_main_function

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

# The JavaCompiler translate nit code from Java code
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

	# Initialize a visitor specific for the compiler engine
	fun new_visitor(filename: String): VISITOR do return new JavaCompilerVisitor(self, filename)

	# Generate java classes repesenting the Nit runtime structures
	fun compile_rtmodel do
		compile_rtclass
		compile_rtmethod
		compile_rtval
	end

	# Compile the Runtime Class structure
	#
	# Classes have 3 attributes:
	# 	* `class_name`: the class name as String
	#   * `vft`: the virtual function table for the class
	#   * `supers`: the super type table
	fun compile_rtclass do
		var v = new_visitor("RTClass.java")
		v.add("import java.util.HashMap;")
		v.add("public abstract class RTClass \{")
		v.add("  public String class_name;")
		v.add("  public HashMap<String, RTMethod> vft = new HashMap<>();")
		v.add("  public HashMap<String, RTClass> supers = new HashMap<>();")
		v.add("  protected RTClass() \{\}")
		v.add("  public void initAttrs(RTVal recv) \{\}")
		v.add("  public void checkAttrs(RTVal recv) \{\}")
		v.add("\}")
	end
	
	# Compile the Runtime Method structure
	#
	# Method body is executed through the `exec` method
	# `exec` always take an array of RTVal as arg, the first one must be the receiver
	# `exec` always a RTVal or null if the Nit return type is void
	fun compile_rtmethod do
		var v = new_visitor("RTMethod.java")
		v.add("public abstract class RTMethod \{")
		v.add("  protected RTMethod() \{\}")
        v.add("  public abstract RTVal exec(RTVal[] args);")
		v.add("\}")
	end

	# Compile the Runtime Value structure
	#
	# RTVal both represents object instances and primitives values:
	#	* object instances:
	#		* `rtclass` represents the class of the RTVal is instance of
	#		* `attrs` contains the attributes of the instance
	#		* `value` must be null
	#	* primitive values:
	#		* `rtclass` represents the class of the primitive value Nit type
	#		* `value` contains the primitive value that can be retrieved by methods likes int_val, bool_val...
	#	* null values:
	#		* they must have both `rtclass` and `value` as null
	fun compile_rtval do
		var v = new_visitor("RTVal.java")
		v.add("import java.util.HashMap;")
		v.add("public class RTVal \{")
		v.add("  public RTClass rtclass;")
		v.add("  public HashMap<String, RTVal> attrs = new HashMap<>();")
		v.add("  Object value;")
		v.add("  public RTVal(RTClass rtclass) \{")
		v.add("    this.rtclass = rtclass;")
		v.add("  \}")
		v.add("  public RTVal(RTClass rtclass, Object value) \{")
		v.add("    this.rtclass = rtclass;")
		v.add("    this.value = value;")
		v.add("  \}")
        v.add("  public int int_val() \{ return (int)value; \}")
		v.add("  public boolean boolean_val() \{ return (boolean)value; \}")
		v.add("  public char char_val() \{ return (char)value; \}")
		v.add("  public double double_val() \{ return (double)value; \}")
		v.add("  public char[] string_val() \{ return (char[])value; \}")
		v.add("  public RTVal[] array_val() \{ return (RTVal[])value; \}")
		v.add("\}")
	end

	# Generated code for all MClass
	#
	# This is a global phase because we need to know all the program 
	# to build attributes, fill vft and type table
	fun compile_mclasses do
		for mclass in mainmodule.model.mclasses do
			compile_mclass(mclass)
		end
	end

	# Generate a Java RTClass for a Nit MClass
	fun compile_mclass(mclass: MClass) do
		var v = new_visitor("{mclass.rt_name}.java")
		v.add("import java.util.HashMap;")
		v.add("public class {mclass.rt_name} extends RTClass \{")
		v.add("  protected static RTClass instance;")
	    v.add("  private {mclass.rt_name}() \{")
		v.add("    this.class_name = \"{mclass.name}\";")
		compile_mclass_vft(v, mclass)
		compile_mclass_type_table(v, mclass)
		v.add("  \}")
		v.add("  public static RTClass get{mclass.rt_name}() \{")
		v.add("    if(instance == null) \{")
		v.add("      instance = new {mclass.rt_name}();")
		v.add("    \}")
		v.add("    return instance;")
		v.add("  \}")
		v.add("  public void initAttrs(RTVal recv) \{")
		compile_mclass_init_attrs(v, mclass)
		v.add("  \}")
		v.add("  public void checkAttrs(RTVal recv) \{")
		compile_mclass_check_attrs(v, mclass)
		v.add("  \}")
		v.add("\}")
	end

	# Compile the virtual function table for the mclass
	fun compile_mclass_vft(v: VISITOR, mclass: MClass) do
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
			v.add("this.vft.put(\"{jname}\", {rt_name}.get{rt_name}());")
			# fill super next definitions
			while mpropdef.has_supercall do
				mpropdef = mpropdef.lookup_next_definition(mainmodule, mclass.intro.bound_mtype)
				rt_name = mpropdef.rt_name
				v.add("this.vft.put(\"{rt_name}\", {rt_name}.get{rt_name}());")
			end
		end
	end

	# Fill the super type table for the MClass
	fun compile_mclass_type_table(v: VISITOR, mclass: MClass) do
		for pclass in mclass.in_hierarchy(mainmodule).greaters do
			if pclass == mclass then
				v.add("supers.put(\"{pclass.jname}\", this);")
			else
				v.add("supers.put(\"{pclass.jname}\", {pclass.rt_name}.get{pclass.rt_name}());")
			end
		end
	end

	# Initialize attributes that are auto-initialized in the Nit code
	fun compile_mclass_init_attrs(v: VISITOR, mclass: MClass) do
		var greaters = mclass.in_hierarchy(mainmodule).greaters.to_a
		mainmodule.linearize_mclasses(greaters)
		for pclass in greaters do
			var mclassdefs = pclass.mclassdefs
			mainmodule.linearize_mclassdefs(mclassdefs)
			for mclassdef in mclassdefs do
				for mpropdef in mclassdef.mpropdefs do
					if mpropdef isa MAttributeDef then
						var apropdef = modelbuilder.mpropdef2npropdef[mpropdef]
						if apropdef isa AAttrPropdef and apropdef.is_initialized then
							apropdef.compile_initialize(v)
						end
					end
				end
			end
		end
	end
	
	# Check that all the non-nullable attributes are initialized after init call
	fun compile_mclass_check_attrs(v: VISITOR, mclass: MClass) do
		var greaters = mclass.in_hierarchy(mainmodule).greaters.to_a
		mainmodule.linearize_mclasses(greaters)
		for pclass in greaters do
			var mclassdefs = pclass.mclassdefs
			mainmodule.linearize_mclassdefs(mclassdefs)
			for mclassdef in mclassdefs do
				for mpropdef in mclassdef.mpropdefs do
					if mpropdef isa MAttributeDef then
						var apropdef = modelbuilder.mpropdef2npropdef[mpropdef]
						if apropdef isa AAttrPropdef then
							apropdef.compile_check(v)
						end
					end
				end
			end
		end
	end

	# Generate code for all MMethodDef
	#
	# This is a separate phase
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

	# Generate a RTMethod java class for each Nit MMethodef
	fun compile_mmethod(mdef: MMethodDef) do
		var v = new_visitor("{mdef.rt_name}.java")
		v.mmethoddef = mdef
		v.add("import java.util.HashMap;")
		v.add("import java.text.DecimalFormat;")
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
		var recv = v.decl_recv
		if not modelbuilder.mpropdef2npropdef.has_key(mdef) then
			compile_implicit_fun(v, mdef)
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
		for decl in v.decls do v.add(decl)
		v.add("\}")
		v.mmethoddef = null
	end

	# Compile an implicit method
	fun compile_implicit_fun(v:VISITOR, mdef: MMethodDef) do
		# compile implicit init and auto initialize attributes
		if mdef.mproperty.is_init then
			compile_free_init(v, mdef)
		else
			print "NOT YET IMPLEMENTED compile_method for {mdef}({mdef.class_name})"
		end
		v.add("return null;")
	end

	# Compile a free constructor
	#
	# Free constructors initialize attributes from arguments and call super
	fun compile_free_init(v: VISITOR, mdef: MMethodDef) do
		# call implicit init super
		var args = new Array[RTVal]
		var j = 1
		for param in mdef.mproperty.intro.msignature.mparameters do
			var arg = v.decl_rtval
			v.add("{arg} = args[{j}];")
			j += 1
			args.add(arg)
		end
		var sup_inits = modelbuilder.mclassdef2nclassdef[mdef.mclassdef].super_inits
		if sup_inits != null then
			for super_init in sup_inits do
				v.compile_monomorphic_call(super_init.intro, v.get_recv, args)
			end
		end
		# init attrs from args
		var i = 1
		var mclassdefs = mdef.mclassdef.mclass.mclassdefs
		v.compiler.mainmodule.linearize_mclassdefs(mclassdefs)
		for mclassdef in mclassdefs do
			for mpropdef in mclassdef.mpropdefs do
				if mpropdef isa MAttributeDef then
					var apropdef = modelbuilder.mpropdef2npropdef[mpropdef]
					if apropdef isa AAttrPropdef and not apropdef.is_initialized then
						apropdef.compile_fromargs(v, i)
						i += 1
					end
				end
			end
		end
	end

	# Generate Java main that call Sys.main
	fun compile_main_function do
		var v = new_visitor("{mainmodule.jname}_Main.java")
		v.add("public class {mainmodule.jname}_Main \{")
		v.add("  public static void main(String[] args) \{")
		if v.has_primitive_mclass("Sys") then
			var sys = v.get_primitive_mclass("Sys")
			v.add("RTVal sys = new RTVal({sys.rt_name}.get{sys.rt_name}());")
			v.add("sys.rtclass.vft.get(\"main\").exec(new RTVal[]\{sys\});")
		end
		v.add("  \}")
		v.add("\}")
	end
end

# The class visiting the AST
#
# A visitor is attached to one JavaFile
class JavaCompilerVisitor
	super Visitor
	type COMPILER: JavaCompiler

	var compiler: JavaCompiler
	var file: JavaFile
	
	# The currently visited MMethodDef or null
	var mmethoddef: nullable MMethodDef

	# Declarations that will be added to the current class
	var decls = new Array[String]

	init(compiler: JavaCompiler, filename: String)
	do
		self.compiler = compiler
		self.file = new JavaFile(filename)
		compiler.files.add(file)
	end

	# Add a line (will be suffixed by `\n`)
	fun add(line: String) do
		file.lines.add("{line}\n")
	end

	# Add a new partial line (no `\n` suffix)
	fun addn(line: String) do
		file.lines.add(line)
	end

	# Add a declaration line in the current class
	fun add_decl(line: String) do
		decls.add(line)
	end

	# Declare a new java runtime value
	#
	# write: "RTVal varX;"
	fun decl_rtval: RTVal do
		var rtval = new RTVal(self)
		add("RTVal {rtval};")
		return rtval
	end

	# Declare the current receiver
	#
	# write: "RTVal recv = args[0];
	fun decl_recv: RTVal do
		var rtval = new RTVal.with_name("recv")
		add("RTVal {rtval} = args[0];")
		return rtval
	end

	fun decl_return: RTVal do
		var rtval = new RTVal.with_name("ret")
		add("RTVal {rtval} = null;")
		return rtval
	end

	# Return the recv RTVal
	fun get_recv: RTVal do
		return new RTVal.with_name("recv")
	end
	
	fun get_return: RTVal do
		return new RTVal.with_name("ret")
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

	fun compile_monomorphic_call(mpropdef: MMethodDef, recv: RTVal, args: Array[RTVal]): RTVal do
		var val = decl_rtval
		var rtargs = [recv]
		rtargs.add_all(args)
		add("{val} = {mpropdef.rt_name}.get{mpropdef.rt_name}().exec(new RTVal[]\{{rtargs.join(",")}\});")
		return val
	end

	fun compile_send(mproperty: MProperty, recv: RTVal, args: Array[RTVal]): RTVal do
		var jname = mproperty.jname
		var val = decl_rtval
		var rtargs = [recv]
		rtargs.add_all(args)
		add("{val} = {recv}.rtclass.vft.get(\"{jname}\").exec(new RTVal[]\{{rtargs.join(",")}\});")
		return val
	end

	fun compile_super(mdef: MMethodDef, recv: RTVal, args: Array[RTVal]): RTVal do
		var mpropdef = mdef.lookup_next_definition(compiler.mainmodule, mdef.mclassdef.bound_mtype)
		var jname = mpropdef.rt_name
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
		add("{recv}.rtclass.initAttrs({recv});")
		compile_callsite(callsite, recv, args)
		add("{recv}.rtclass.checkAttrs({recv});")
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

	fun has_primitive_mclass(name: String): Bool do
		return compiler.mainmodule.model.get_mclasses_by_name(name) != null
	end

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
		var recv = decl_rtval
		add("{recv} = new RTVal({mclass_box.rt_name}.get{mclass_box.rt_name}(), {rtval});")
		return recv
	end

	# box concrete primitive values (Int, Float, Bool, Char) to RTVal
	fun box_value(value: nullable Object): RTVal do
		if value == null then
			var recv = decl_rtval
			add("{recv} = new RTVal(null, null);")
			return recv
		else if value isa Int then
			var mbox = get_primitive_mclass("Int")
			var recv = decl_rtval
			add("{recv} = new RTVal({mbox.rt_name}.get{mbox.rt_name}(), {value});")
			return recv
		else if value isa Bool then
			var mbox = get_primitive_mclass("Bool")
			var recv = decl_rtval
			add("{recv} = new RTVal({mbox.rt_name}.get{mbox.rt_name}(), {value});")
			return recv
		else if value isa Float then
			var mbox = get_primitive_mclass("Float")
			var recv = decl_rtval
			add("{recv} = new RTVal({mbox.rt_name}.get{mbox.rt_name}(), {value});")
			return recv
		else if value isa Char then
			var mbox = get_primitive_mclass("Char")
			var recv = decl_rtval
			add("{recv} = new RTVal({mbox.rt_name}.get{mbox.rt_name}(), '{value.to_s.escape_to_c}');")
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

redef class AAsCastExpr
	redef fun expr(v) do
		var recv = v.expr(n_expr)
		var mclass = n_type.mtype.as(MClassType).mclass
		var res = new RTVal(v)
		v.add("boolean {res} = {recv}.rtclass.supers.get(\"{mclass.jname}\") == {mclass.rt_name}.get{mclass.rt_name}();")
		v.add("if(!{res}) \{")
		v.add("  System.err.println(\"Runtime error: Cast failed. Expected `{n_type.mtype.as(not null).to_s}`, got `\" + {recv}.rtclass.class_name + \"` ({location.short_location})\");")
		v.add("  System.exit(1);")
		v.add("\}")
		return recv
	end
end

redef class AAssertExpr
	redef fun compile(v) do
		var exp = v.expr(n_expr)
		v.add("if(!{exp}.boolean_val()) \{")
		if n_else != null then
			v.add("if(true) \{")
			v.compile(n_else.as(not null))
			v.add("\}")
		end
		if n_id != null then
			v.add("  System.err.println(\"Runtime error: Assert '{n_id.text}' failed ({location.short_location})\");")
		else
			v.add("  System.err.println(\"Runtime error: Assert failed ({location.short_location})\");")
		end
		v.add("  System.exit(1);")
		v.add("\}")
	end
end

redef class AAbortExpr
	redef fun compile(v) do
		v.add("System.err.println(\"Runtime error: Aborted ({location.short_location})\");")
		v.add("System.exit(1);")
	end
end

redef class AAndExpr
	redef fun expr(v) do
		var val = new RTVal(v)
		var exp1 = v.expr(n_expr)
		var exp2 = v.expr(n_expr2)
		v.add("boolean {val} = ({exp1}.boolean_val() && {exp2}.boolean_val());")
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
		v.add("  System.err.println(\"Runtime error: Cast failed ({location.short_location})\");")
		v.add("  System.exit(1);")
		v.add("\}")
		return exp
	end
end

redef class AAttrExpr
	redef fun expr(v) do
		var recv = v.expr(n_expr)
		var val = v.decl_rtval
		v.add("if({recv}.attrs.get(\"{mproperty.jname}\") == null) \{")
		v.add("  System.err.println(\"Runtime error: Uninitialized attribute {mproperty.name} ({location.short_location})\");")
		v.add("  System.exit(1);")
		v.add("\}")
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

	fun compile_initialize(v: VISITOR) do
		var recv = v.get_recv
		var val = v.expr(n_expr.as(not null))
		v.add("{recv}.attrs.put(\"{mpropdef.mproperty.jname}\", {val});")
	end
	
	fun compile_check(v: VISITOR) do
		var recv = v.get_recv
		v.add("if({recv}.attrs.get(\"{mpropdef.mproperty.jname}\") == null) \{")
		v.add("  System.err.println(\"Runtime error: Uninitialized attribute {mpropdef.mproperty.name} ({location.short_location})\");")
		v.add("  System.exit(1);")
		v.add("\}")
	end

	fun compile_fromargs(v: VISITOR, index: Int) do
		var recv = v.get_recv
		v.add("{recv}.attrs.put(\"{mpropdef.mproperty.jname}\", args[{index}]);")
	end

	fun compile_setter(v: VISITOR) do
		var val = v.decl_rtval
		v.add("{val} = args[1];")
		v.add("{v.get_recv}.attrs.put(\"{mpropdef.mproperty.jname}\", {val});")
		v.add("return null;")
	end

	fun compile_getter(v: VISITOR) do
		var res = v.decl_rtval
		compile_check(v)
		v.add("{res} = {v.get_recv}.attrs.get(\"{mpropdef.mproperty.jname}\");")
		v.add("return {res};")
	end
end

redef class AAttrReassignExpr
	redef fun compile(v) do
		var callsite = reassign_callsite.as(not null)
		var recv = v.expr(n_expr)
		var val = v.expr(n_value)
		var old = v.decl_rtval
		v.add("if({recv}.attrs.get(\"{mproperty.jname}\") == null) \{")
		v.add("  System.err.println(\"Runtime error: Uninitialized attribute {mproperty.name} ({location.short_location})\");")
		v.add("  System.exit(1);")
		v.add("\}")
		v.add("{old} = {recv}.attrs.get(\"{mproperty.jname}\");")
		var rtnew = v.compile_callsite(callsite, old, [val])
		v.add("{recv}.attrs.put(\"{mproperty.jname}\", {rtnew});")
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

redef class ABreakExpr
	redef fun compile(v) do
		if n_label != null then
			v.add("break _{n_label.n_id.text};")
		else
			v.add("break;")
		end
	end
end

redef class ADeferredMethPropdef
	redef fun compile(v) do
		v.add("System.err.println(\"Runtime error: Abstract method `{mpropdef.mproperty.name}` called on `{mpropdef.mclassdef.mclass.name}` ({location.short_location})\");")
		v.add("return null;")
	end
end

redef class ADoExpr
	redef fun compile(v) do
		if n_label != null then v.add("_{n_label.n_id.text}:")
		v.add("do \{")
		if n_block != null then v.compile(n_block.as(not null))
		v.add("\} while(false);")
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
		var ret = v.decl_return
		if n_block != null then
			v.add("_return: do \{")
			if n_signature != null then
				var i = 1
				for param in n_signature.n_params do
					var val = v.decl_var(param.variable.as(not null))
					v.add("{val} = args[{i}];")
					i += 1
				end
			end
			v.compile(n_block.as(not null))
			v.add("\} while(false);")
		end
		v.add("return {v.get_return};")
	end
end

redef class AConcreteInitPropdef
	redef fun compile(v) do
		if not mpropdef.has_supercall then
			# call implicit init super
			var args = new Array[RTVal]
			var j = 1
			for param in mpropdef.mproperty.intro.msignature.mparameters do
				var arg = v.decl_rtval
				v.add("{arg} = args[{j}];")
				j += 1
				args.add(arg)
			end
			var sup_inits = self.auto_super_inits
			if sup_inits != null then
				for super_init in sup_inits do
					v.compile_monomorphic_call(super_init.intro, v.get_recv, args)
				end
			end
		end
		super
	end
end

redef class AContinueExpr
	redef fun compile(v) do
		if n_label != null then
			v.add("continue _{n_label.n_id.text};")
		else
			v.add("continue;")
		end
	end
end

redef class ACrangeExpr
	redef fun expr(v) do
		var rstart = v.expr(n_expr)
		var rend = v.expr(n_expr2)
		# init Range
		var mrange = v.get_primitive_mclass("Range")
		var recv = v.decl_rtval
		v.add("{recv} = new RTVal({mrange.rt_name}.get{mrange.rt_name}());")
		# call init.without_last
		var args = [recv, rstart, rend]
		v.add("{recv}.rtclass.vft.get(\"init\").exec(new RTVal[]\{{args.join(",")}\});")
		return recv
	end
end

redef class AEqExpr
	redef fun expr(v) do
		var mclass = v.get_primitive_mclass("Bool")
		var exp1 = v.expr(n_expr)
		var exp2 = v.expr(n_expr2)
		var res = new RTVal(v)
		v.add("boolean {res};")
		v.add("if({exp1}.rtclass == null) \{")
		v.add("  {res} = {exp2}.rtclass == null;")
		v.add("\} else if({exp1}.value == null) \{")
		v.add("  {res} = {super.as(not null)}.boolean_val();")
		v.add("\} else \{")
		v.add("  {res} = {exp1}.value.equals({exp2}.value);")
		v.add("\}")
		return v.box_rtval(res, mclass)
	end
end

redef class AEndStringExpr
	redef fun expr(v) do
		var str = new RTVal(v)
		v.add("String {str} = \"{value.to_s.escape_to_c}\";")
		return str
	end
end

redef class AExternInitPropdef
	redef fun compile(v) do
		print "NOT YET IMPL. AExternInitPropdef::compile for {mpropdef.to_s}"
		v.add("return null;")
	end
end

redef class AExternMethPropdef
	redef fun compile(v) do
		var mprop = mpropdef.mproperty
		var recv = v.decl_rtval
		v.add("{recv} = args[0];")

		# primitive mapping to java
		if mprop.name == "native_int_to_s" then
			var box_mclass = v.get_primitive_mclass("NativeString")
			var res = new RTVal(v)
			v.add("char[] {res} = String.valueOf({recv}.int_val()).toCharArray();")
			v.add("return {v.box_rtval(res, box_mclass)};")
			return
		end
		print "NOT YET IMPL. AExternMethPropdef::compile for {mpropdef.to_s}"
		v.add("return null;")
	end
end

redef class AFalseExpr
	redef fun expr(v) do return v.box_value(false)
end

redef class AFloatExpr
	redef fun expr(v) do return v.box_value(value.as(not null))
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
			# label:
			if n_label != null then v.add("_{n_label.n_id.text}:")
			# while(true) do
			v.add("while(true) \{")
			# var is_ok = it.is_ok
			var it_isok = v.compile_send(mit_isok, it, new Array[RTVal])
			#	if not is_ok then break
			v.add("if(!{it_isok}.boolean_val()) \{ break; \}")
			#   var i = it.item
			var i = v.decl_var(variables.first)
			var item = v.compile_send(mit_item, it, new Array[RTVal])
			v.add("{i} = {item};")
			#   it.next
			v.compile_send(mit_next, it, new Array[RTVal])
			#   ...
			if n_block != null then v.compile(n_block.as(not null))
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
			# label:
			if n_label != null then v.add("_{n_label.n_id.text}:")
			# while(true) do
			v.add("while(true) \{")
			# var is_ok = it.is_ok
			var it_isok = v.compile_send(mit_isok, it, new Array[RTVal])
			#	if not is_ok then break
			v.add("if(!{it_isok}.boolean_val()) \{ break; \}")
			#   var i = it.item
			var i = v.decl_var(variables.first)
			var item = v.compile_send(mit_item, it, new Array[RTVal])
			v.add("{i} = {item};")
			#   var j = it.key
			var j = v.decl_var(variables[1])
			var key = v.compile_send(mit_key, it, new Array[RTVal])
			v.add("{j} = {key};")
			#   it.next
			v.compile_send(mit_next, it, new Array[RTVal])
			#   ...
			if n_block != null then v.compile(n_block.as(not null))
			# end
			v.add("\}")
		end
	end
end

redef class AIfExpr
	redef fun compile(v) do
		var val = v.expr(n_expr)
		v.add("if ({val}.boolean_val()) \{")
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

redef class AIfexprExpr
	redef fun expr(v) do
		var res = v.decl_rtval
		var val = v.expr(n_expr)
		v.add("if ({val}.boolean_val()) \{")
		var then_expr = v.expr(n_then)
		v.add("{res} = {then_expr};")
		v.add("\} else \{")
		var else_expr = v.expr(n_else)
		v.add("{res} = {else_expr};")
		v.add("\}")
		return res
	end
end

redef class AImplicitSelfExpr
	redef fun expr(v) do return v.get_recv
end

redef class AImpliesExpr
	redef fun expr(v) do
		var val = new RTVal(v)
		var exp1 = v.expr(n_expr)
		var exp2 = v.expr(n_expr2)
		v.add("boolean {val} = !({exp1}.boolean_val() && !{exp2}.boolean_val());")
		var mclass = v.get_primitive_mclass("Bool")
		return v.box_rtval(val, mclass)
	end
end

redef class AInitExpr
	redef fun compile(v) do
		var callsite = self.callsite.as(not null)
		var recv = v.expr(n_expr)
		var args = new Array[RTVal]
		for raw_arg in raw_arguments do args.add(v.expr(raw_arg))
		v.compile_callsite(callsite, recv, args)
	end
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
				v.add("boolean {res};")
				v.add("if({exp}.value == null) \{")
				v.add("   {res} = {recv}.hashCode() == {exp}.hashCode();")
				v.add("\} else \{")
				v.add("  {res} = {recv}.value.equals({exp}.value);")
				v.add("\}")
				v.add("return {v.box_rtval(res, box_mclass)};")
				return
			else if mprop.name == "is_same_type" then
				var box_mclass = v.get_primitive_mclass("Bool")
				var exp = v.decl_rtval
				var res = new RTVal(v)
				v.add("{exp} = args[1];")
				v.add("boolean {res} = {recv}.rtclass == {exp}.rtclass;")
				v.add("return {v.box_rtval(res, box_mclass)};")
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
				v.add("int {id} = {recv}.boolean_val() ? 1 : 0;")
				var box = v.box_rtval(id, box_int)
				v.add("return {box};")
			else if mprop.name == "output" then
				v.add("System.out.println({recv}.boolean_val());")
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
				v.add("int {res} = -({recv}.int_val());")
				var box = v.box_rtval(res, box_int)
				v.add("return {box};")
			else if mprop.name == "succ" then
				var res = new RTVal(v)
				v.add("int {res} = ({recv}.int_val() + 1);")
				var box = v.box_rtval(res, box_int)
				v.add("return {box};")
			else if mprop.name == "prec" then
				var res = new RTVal(v)
				v.add("int {res} = ({recv}.int_val() - 1);")
				var box = v.box_rtval(res, box_int)
				v.add("return {box};")
			else if mprop.name == "to_f" then
				var box_f = v.get_primitive_mclass("Float")
				var res = new RTVal(v)
				v.add("double {res} = (double){recv}.int_val();")
				var box = v.box_rtval(res, box_f)
				v.add("return {box};")
			else if mprop.name == "ascii" then
				var box_c = v.get_primitive_mclass("Char")
				var res = new RTVal(v)
				v.add("char {res} = (char){recv}.int_val();")
				var box = v.box_rtval(res, box_c)
				v.add("return {box};")
			else if mprop.name == "object_id" then
				var id = new RTVal(v)
				v.add("int {id} = {recv}.int_val();")
				var box = v.box_rtval(id, box_int)
				v.add("return {box};")
			else if mprop.name == "output" then
				v.add("System.out.println({recv}.int_val());")
				v.add("return null;")
			end
			return
		else if mclass.name == "Float" then # Float primnitive
			var box_double = v.get_primitive_mclass("Float")
			if mprop.name == "<=" then
				compile_bool_op(v, recv, "double", "<=")
			else if mprop.name == "<" then
				compile_bool_op(v, recv, "double", "<")
			else if mprop.name == ">=" then
				compile_bool_op(v, recv, "double", ">=")
			else if mprop.name == ">" then
				compile_bool_op(v, recv, "double", ">")
			else if mprop.name == "+" then
				compile_double_op(v, recv, "+")
			else if mprop.name == "-" then
				compile_double_op(v, recv, "-")
			else if mprop.name == "*" then
				compile_double_op(v, recv, "*")
			else if mprop.name == "/" then
				compile_double_op(v, recv, "/")
			else if mprop.name == "unary -" then
				var res = new RTVal(v)
				v.add("double {res} = -({recv}.double_val());")
				var box = v.box_rtval(res, box_double)
				v.add("return {box};")
			else if mprop.name == "to_i" then
				var box_i = v.get_primitive_mclass("Int")
				var res = new RTVal(v)
				v.add("int {res} = (int){recv}.double_val();")
				var box = v.box_rtval(res, box_i)
				v.add("return {box};")
			else if mprop.name == "object_id" then
				var box_int = v.get_primitive_mclass("Int")
				var id = new RTVal(v)
				v.add("int {id} = {recv}.int_val();")
				var box = v.box_rtval(id, box_int)
				v.add("return {box};")
			else if mprop.name == "output" then
				var df = new RTVal(v)
				v.add("DecimalFormat df = new DecimalFormat(\"0.000000\");")
				v.add("System.out.println(df.format({recv}.double_val()));")
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
				v.add("int {res} = ({recv}.char_val() + 1);")
				var box = v.box_rtval(res, box_char)
				v.add("return {box};")
			else if mprop.name == "prec" then
				var res = new RTVal(v)
				v.add("int {res} = ({recv}.char_val() - 1);")
				var box = v.box_rtval(res, box_char)
				v.add("return {box};")
			else if mprop.name == "ascii" then
				var box_i = v.get_primitive_mclass("Int")
				var res = new RTVal(v)
				v.add("int {res} = (int){recv}.char_val();")
				var box = v.box_rtval(res, box_i)
				v.add("return {box};")
			else if mprop.name == "object_id" then
				var box_int = v.get_primitive_mclass("Int")
				var id = new RTVal(v)
				v.add("int {id} = {recv}.char_val();")
				var box = v.box_rtval(id, box_int)
				v.add("return {box};")
			else if mprop.name == "output" then
				v.add("System.out.print({recv}.char_val());")
				v.add("return null;")
			end
			return
		else if mclass.name == "NativeArray" then
			if mprop.name == "[]" then
				v.add("return {recv}.array_val()[args[1].int_val()];")
			else if mprop.name == "[]=" then
				v.add("{recv}.array_val()[args[1].int_val()] = args[2];")
				v.add("return null;")
			else if mprop.name == "copy_to" then
				var i = new RTVal(v)
				var dest = v.decl_rtval
				v.add("{dest} = args[1];")
				v.add("for(int {i} = 0; {i} < {recv}.array_val().length; {i}++) \{")
				v.add("  {dest}.array_val()[{i}] = {recv}.array_val()[{i}];")
				v.add("\}")
				v.add("return null;")
			end
			return
		else if mclass.name == "NativeString" then
				var box_char = v.get_primitive_mclass("Char")
				var box_int = v.get_primitive_mclass("Int")
			if mprop.name == "[]" then
				var char = new RTVal(v)
				v.add("char {char} = {recv}.string_val()[args[1].int_val()];")
				v.add("return {v.box_rtval(char, box_char)};")
			else if mprop.name == "[]=" then
				v.add("{recv}.string_val()[args[1].int_val()] = args[2].char_val();")
				v.add("return null;")
			else if mprop.name == "copy_to" then
				var i = new RTVal(v)
				var dest = v.decl_rtval
				var length = v.decl_rtval
				var from = v.decl_rtval
				var to = v.decl_rtval
				v.add("{dest} = args[1];")
				v.add("{length} = args[2];")
				v.add("{from} = args[3];")
				v.add("{to} = args[4];")
				var j = new RTVal(v)
				v.add("int {j} = {from}.int_val();")
				v.add("for(int {i} = {to}.int_val(); {i} < ({to}.int_val() + {length}.int_val()); {i}++) \{")
				v.add("  {dest}.string_val()[{i}] = {recv}.string_val()[{j}];")
				v.add("  {j}++;")
				v.add("\}")
				v.add("return null;")
			else if mprop.name == "atoi" then
				var int = new RTVal(v)
				v.add("int {int} = Integer.parseInt(String.valueOf({recv}.string_val()));")
				v.add("return {v.box_rtval(int, box_int)};")
			end
			return
		else if mclass.name == "ArrayCapable" then
			if mprop.name == "calloc_array" then
				var box_arr = v.get_primitive_mclass("NativeArray")
				var arr = new RTVal(v)
				v.add("RTVal[] {arr} = new RTVal[args[1].int_val()];")
				var box = v.box_rtval(arr, box_arr)
				v.add("return {box};")
				return
			end
		else if mclass.name == "StringCapable" then
			if mprop.name == "calloc_string" then
				var box_str = v.get_primitive_mclass("NativeString")
				var str = new RTVal(v)
				v.add("char[] {str} = new char[args[1].int_val()];")
				var box = v.box_rtval(str, box_str)
				v.add("return {box};")
				return
			end
		end
		print "NOT YET IMPL. AInternMethPropdef::compile for {mpropdef.to_s}"
		#TODO missing primitives
		v.add("return null;")
	end

	private fun compile_bool_op(v: JavaCompilerVisitor, recv: RTVal, jtype: String, op: String) do
		var box_bool = v.get_primitive_mclass("Bool")
		var exp = v.decl_rtval
		v.add("{exp} = args[1];")
		var res = new RTVal(v)
		if op == "==" or op == "!=" then
			v.add("boolean {res} = {recv}.value {op} {exp}.value;")
		else
			v.addn("boolean {res} = ({recv}.value != null && {exp}.value != null)")
			v.add(" && ({recv}.{jtype}_val() {op} {exp}.{jtype}_val());")
		end
		var box = v.box_rtval(res, box_bool)
		v.add("return {box};")
	end

	private fun compile_int_op(v: JavaCompilerVisitor, recv: RTVal, op: String) do
		var box_int = v.get_primitive_mclass("Int")
		var exp = v.decl_rtval
		v.add("{exp} = args[1];")
		var res = new RTVal(v)
		v.add("int {res} = ({recv}.int_val() {op} {exp}.int_val());")
		var box = v.box_rtval(res, box_int)
		v.add("return {box};")
	end

	private fun compile_double_op(v: JavaCompilerVisitor, recv: RTVal, op: String) do
		var box_double = v.get_primitive_mclass("Float")
		var exp = v.decl_rtval
		v.add("{exp} = args[1];")
		var res = new RTVal(v)
		v.add("double {res} = ({recv}.double_val() {op} {exp}.double_val());")
		var box = v.box_rtval(res, box_double)
		v.add("return {box};")
	end

	private fun compile_char_op(v: JavaCompilerVisitor, recv: RTVal, op: String) do
		var box_char = v.get_primitive_mclass("Char")
		var exp = v.decl_rtval
		v.add("{exp} = args[1];")
		var res = new RTVal(v)
		v.add("char {res} = (char)({recv}.char_val() {op} {exp}.int_val());")
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

redef class AIssetAttrExpr
	redef fun expr(v) do
		var exp = v.expr(n_expr)
		var recv = v.get_recv
		var val = new RTVal(v)
		v.add("boolean {val} = {recv}.attrs.get(\"{mproperty.jname}\") != null;")
		var mclass = v.get_primitive_mclass("Bool")
		return v.box_rtval(val, mclass)
	end
end

redef class ALoopExpr
	redef fun compile(v) do
		if n_label != null then v.add("_{n_label.n_id.text}:")
		v.add("while(true) \{")
		if not n_block == null then v.compile(n_block.as(not null))
		v.add("if(false) \{ break; \}")
		v.add("\}")
	end
end

redef class AMidStringExpr
	redef fun expr(v) do
		var str = new RTVal(v)
		v.add("String {str} = \"{value.to_s.escape_to_c}\";")
		return str
	end
end

redef class ANotExpr
	redef fun expr(v) do
		var exp = v.expr(n_expr)
		var val = new RTVal(v)
		v.add("boolean {val} = !{exp}.boolean_val();")
		var mclass = v.get_primitive_mclass("Bool")
		return v.box_rtval(val, mclass)
	end
end

redef class ANeExpr
	redef fun expr(v) do
		var mclass = v.get_primitive_mclass("Bool")
		var exp1 = v.expr(n_expr)
		var exp2 = v.expr(n_expr2)
		var res = new RTVal(v)
		v.add("boolean {res};")
		v.add("if({exp1}.rtclass == null) \{")
		v.add("  {res} = {exp2}.rtclass != null;")
		v.add("\}else if({exp1}.value == null) \{")
		v.add("  {res} = {super.as(not null)}.boolean_val();")
		v.add("\} else \{")
		v.add("  {res} = !({exp1}.value.equals({exp2}.value));")
		v.add("\}")
		return v.box_rtval(res, mclass)
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

redef class AOnceExpr
	redef fun expr(v) do
		var res = v.decl_rtval
		var cache = new RTVal(v)
		var guard = new RTVal(v)
		v.add_decl("RTVal {cache};")
		v.add_decl("boolean {guard} = false;")
		v.add("if(!{guard}) \{")
		var exp = v.expr(n_expr)
		v.add("{guard} = true;")
		v.add("{cache} = {exp};")
		v.add("{res} = {cache};")
		v.add("\} else \{")
		v.add("{res} = {cache};")
		v.add("\}")
		return res
	end
end

redef class AOrExpr
	redef fun expr(v) do
		var val = new RTVal(v)
		var exp1 = v.expr(n_expr)
		var exp2 = v.expr(n_expr2)
		v.add("boolean {val} = ({exp1}.boolean_val() || {exp2}.boolean_val());")
		var mclass = v.get_primitive_mclass("Bool")
		return v.box_rtval(val, mclass)
	end
end

redef class AOrangeExpr
	redef fun expr(v) do
		var rstart = v.expr(n_expr)
		var rend = v.expr(n_expr2)
		# init Range
		var mrange = v.get_primitive_mclass("Range")
		var recv = v.decl_rtval
		v.add("{recv} = new RTVal({mrange.rt_name}.get{mrange.rt_name}());")
		# call init.without_last
		var args = [recv, rstart, rend]
		v.add("{recv}.rtclass.vft.get(\"without_last\").exec(new RTVal[]\{{args.join(",")}\});")
		return recv
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
			v.add("{v.get_return} = {expr};")
		end
		v.add("break _return;")
	end
end

redef class ASelfExpr
	redef fun expr(v) do return v.get_recv
end

redef class AStartStringExpr
	redef fun expr(v) do
		var str = new RTVal(v)
		v.add("String {str} = \"{value.to_s.escape_to_c}\";")
		return str
	end
end

redef class AStringExpr
	redef fun expr(v) do
		# init NativeString
		var string = new RTVal(v)
		v.add("char[] {string} = \"{value.to_s.escape_to_c}\".toCharArray();")
		var mnative = v.get_primitive_mclass("NativeString")
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

redef class ASuperExpr
	redef fun expr(v) do
		var recv = v.get_recv
		var args = new Array[RTVal]
		if n_args.n_exprs.is_empty then
			var i = 1
			for param in v.mmethoddef.mproperty.intro.msignature.mparameters do
				var arg = v.decl_rtval
				v.add("{arg} = args[{i}];")
				i += 1
				args.add(arg)
			end
		else
			for arg in n_args.n_exprs do args.add(v.expr(arg))
		end
		if mproperty != null then
			return v.compile_send(mproperty.as(not null), recv, args)
		else
			return v.compile_super(v.mmethoddef.as(not null), recv, args)
		end
	end

	redef fun compile(v) do expr(v)
end

redef class ASuperstringExpr
	redef fun expr(v) do
		var str = new RTVal(v)
		v.add("String {str} = \"\";")
		for n_expr in n_exprs do
			var sub = v.expr(n_expr)
			v.add("{str} += {sub};")
		end
		var strn = new RTVal(v)
		v.add("char[] {strn} = {str}.toCharArray();")
		var mnative = v.get_primitive_mclass("NativeString")
		var nbox = v.box_rtval(strn, mnative)
		# init String
		var mstring = v.get_primitive_mclass("String")
		var recv = v.decl_rtval
		v.add("{recv} = new RTVal({mstring.rt_name}.get{mstring.rt_name}());")
		# call init.with_infos
		var mint = v.get_primitive_mclass("Int")
		var rtlenm = new RTVal(v)
		v.add("int {rtlenm} = {str}.length();")
		var rtlen = v.box_rtval(rtlenm, mint)
		var rtfrom = v.box_value(0)
		var rtton = new RTVal(v)
		v.add("int {rtton} = {rtlenm} - 1;")
		var rtto = v.box_rtval(rtton, mint)
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
		var res = v.compile_callsite(callsite, recv, args)
		v.add("{recv} = {res};")
	end
end

redef class AWhileExpr
	redef fun compile(v) do
		if n_label != null then v.add("_{n_label.n_id.text}:")
		v.add("while(true) \{")
		var exp = v.expr(n_expr)
		v.add("if(!{exp}.boolean_val()) \{ break; \}")
		if n_block != null then v.compile(n_block.as(not null))
		v.add("\}")
	end
end

