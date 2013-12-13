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
	# --compile-dir
	var opt_compile_dir: OptionString = new OptionString("Directory used to generate temporary files", "--compile-dir")

	redef init do
		super
		self.option_context.add_option(self.opt_compile_dir)
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
		var orig_dir=".." # FIXME only works if `compile_dir` is a subdirectory of cwd
		var outpath = orig_dir

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
		var manifname = "{mainmodule.name}.mf"
		var manifpath = "{compile_dir}/{manifname}"
		var maniffile = new OFStream.open(manifpath)
		maniffile.write("Manifest-Version: 1.0\n")
		maniffile.write("Main-Class: Main\n")
		maniffile.close

		# Generate the Makefile
		var makename = "{mainmodule.name}.mk"
		var makepath = "{compile_dir}/{makename}"
		var makefile = new OFStream.open(makepath)

		makefile.write("javac = javac\n\n")
		makefile.write("jar = jar\n\n")

		makefile.write("all: {outpath}\n\n")

		# Compile each generated file
		var ofiles = new List[String]
		for f in jfiles do
			var o = f.strip_extension(".java") + ".class"
			makefile.write("{o}: {f}\n\t$(javac) {f}\n\n")
			ofiles.add(o)
		end

		# Link edition
		makefile.write("{outpath}: {ofiles.join(" ")}\n\t$(jar) cfm {outpath}/{mainmodule.name}.jar {manifname} {ofiles.join(" ")}\n\n")

		# Clean
		makefile.write("clean:\n\trm {ofiles.join(" ")} 2>/dev/null\n\n")
		makefile.close
		self.toolcontext.info("Generated makefile: {makepath}", 2)

		var time1 = get_time
		self.toolcontext.info("*** END WRITING C: {time1-time0} ***", 2)

		# Execute the Makefile
		time0 = time1
		self.toolcontext.info("*** COMPILING C ***", 1)
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
		self.toolcontext.info("*** END COMPILING C: {time1-time0} ***", 2)
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
		v.add("import java.util.Map;")
		v.add("public abstract class RTClass \{")
		v.add("  public Map<String, RTMethod> vft;")
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
		v.add("import java.util.Map;")
		v.add("public class RTVal \{")
		v.add("  public RTClass rtclass;")
		v.add("  public Map<String, Object> attributes;")
		v.add("  public RTVal(RTClass rtclass, Map<String, Object> attributes) \{")
		v.add("    this.rtclass = rtclass;")
		v.add("    this.attributes = attributes;")
		v.add("  \}")
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
		v.add("    this.vft = new HashMap<>();")

		# fill vft
		for pclass in mclass.in_hierarchy(mainmodule).greaters do
			for mclassdef in pclass.mclassdefs do
				for mprop in mclassdef.intro_mproperties do
					var mpropdef = mprop.lookup_first_definition(mainmodule, pclass.mclass_type)
					v.add("    this.vft.put(\"{mprop.jname}\", {mpropdef.rt_name}.get{mpropdef.rt_name}());")
				end
			end
		end

		v.add("  \}")
		v.add("  public static RTClass get{mclass.rt_name}() \{")
		v.add("    if(instance == null) \{")
		v.add("      instance = new {mclass.rt_name}();")
		v.add("    \}")
		v.add("    return instance;")
		v.add("  \}")
		v.add("\}")
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
		if not modelbuilder.mpropdef2npropdef.has_key(mdef) then
			print "NOT YET IMPLEMENTED compile_method for {mdef}({mdef.class_name})"
			return
		end
		var apropdef = modelbuilder.mpropdef2npropdef[mdef]
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
		apropdef.compile(v)
		if mdef.msignature.return_mtype == null then
			v.add("    return null;")
		end
		v.add("  \}")
		v.add("\}")
	end

	# generate Java main
	fun compile_main_function do
		var v = new_visitor("Main.java")
		v.add("public class Main \{")
		v.add("public static void main(String[] args) \{")
		v.addn("RTMethod_{mainmodule.jname}_Sys_main.getRTMethod_{mainmodule.jname}_Sys_main()")
		v.add(".exec(new RTVal[]\{\});")
		v.add("\}")
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

	redef fun visit(e) do
		e.compile(self)
	end

	fun new_var(name: String): RTVal do
		var rtval = new RTVal.with_name(get_name(name))
		add("RTVal {rtval};")
		return rtval
	end

	fun decl_var(variable: Variable): RTVal do
		var rtval = new_var(variable.name)
		var2rtval[variable] = rtval
		return rtval
	end

	fun get_var(variable: Variable): RTVal do
		if not var2rtval.has_key(variable) then
			print "var {variable} must be declared firt. use decl_var"
			abort
		end
		return var2rtval[variable]
	end
	var var2rtval = new HashMap[Variable, RTVal]

	fun compile_send(callsite: CallSite, args: Array[RTVal]) do
		var rt_args = new Array[String]
		for arg in args do rt_args.add(arg.rt_name)
		var recv = args[0]
		addn("{recv}.rtclass.vft.get(\"{callsite.mproperty.jname}\").exec(")
		addn("new RTVal[]\{{rt_args.join(",")}\}")
		addn(")")
	end

	fun compile(expr: AExpr) do
		expr.compile(self)
	end

	fun expr(expr: AExpr): RTVal do
		return expr.expr(self).as(not null)
	end

	fun stmt(expr: AExpr) do
		expr.stmt(self)
	end

	fun get_name(name: String): String do
		counter += 1
		return "{name}{counter}"
	end
	var counter = 0
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
		self.rt_name = v.get_name("var")
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

	fun stmt(v: VISITOR) do
		print "NOT YET IMPL. AEXPR::stmt for {class_name}"
	end
end

redef class ABlockExpr
	redef fun compile(v) do for exp in n_expr do v.stmt(exp)
end

redef class ACallExpr
	redef fun stmt(v) do
		var recv = v.expr(n_expr)
		var args = [recv]
		for raw_arg in raw_arguments do
			var arg = v.expr(raw_arg)
			args.add(arg)
		end
		v.compile_send(callsite.as(not null), args)
		v.add(";")
	end
end

redef class AConcreteMethPropdef
	redef fun compile(v) do if n_block != null then v.compile(n_block.as(not null))
end

redef class AImplicitSelfExpr
	redef fun expr(v) do return v.get_var(variable.as(not null))
end

redef class AIntExpr
	redef fun compile(v) do
		v.addn("new RTVal({value.to_s})")
	end
end

redef class ANewExpr
	redef fun expr(v) do
		var mclass = n_type.mtype.as(MClassType).mclass
		var args = new RTVal(v)
		v.add("HashMap<String, Object> {args} = new HashMap<>();")
		for raw_arg in n_args.n_exprs do
			var arg = v.expr(raw_arg)
			v.add("{args}.put(\"name\", {arg})")
		end
		var recv = new RTVal(v)
		v.add("RTVal {recv} = new RTVal({mclass.rt_name}.get{mclass.rt_name}(), {args});")
		#TODO call initializer
		#TODO named consts?
		return recv
	end
end

redef class AVarExpr
	redef fun expr(v) do
		return v.get_var(variable.as(not null))
	end

	redef fun compile(v) do
		v.addn(v.get_var(variable.as(not null)).rt_name)
	end
end

redef class AVardeclExpr
	redef fun stmt(v) do
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
		v.addn(v.get_var(variable.as(not null)).rt_name)
		v.addn(" = ")
		n_value.compile(v)
		v.add(";")
		visit_all(v)
	end
end


# tokens

redef class TAssign
	redef fun compile(v) do v.addn(" = ")
end

redef class TId
	redef fun compile(v) do
		v.addn(text)
	end
end

redef class TKwvar
	redef fun compile(v) do
		v.addn("RTVal ")
	end
end


