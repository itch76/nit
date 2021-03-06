#include "nit.common.h"
extern const int COLOR_time__Object__get_time;
extern const int COLOR_modelbuilder__ModelBuilder__toolcontext;
val* string__NativeString__to_s_with_length(char* self, long p0);
extern const int COLOR_toolcontext__ToolContext__info;
val* NEW_global_compiler__GlobalCompiler(const struct type* type);
extern const struct type type_global_compiler__GlobalCompiler;
extern const int COLOR_global_compiler__GlobalCompiler__init;
void CHECK_NEW_global_compiler__GlobalCompiler(val*);
extern const int COLOR_abstract_compiler__AbstractCompiler__compile_header;
extern const int COLOR_rapid_type_analysis__RapidTypeAnalysis__live_types;
extern const int COLOR_abstract_collection__Collection__iterator;
extern const int COLOR_abstract_collection__Iterator__is_ok;
extern const int COLOR_abstract_collection__Iterator__item;
extern const int COLOR_global_compiler__GlobalCompiler__declare_runtimeclass;
extern const int COLOR_abstract_collection__Iterator__next;
extern const int COLOR_global_compiler__GlobalCompiler__compile_class_names;
extern const int COLOR_abstract_compiler__MType__ctype;
extern const int COLOR_kernel__Object___61d_61d;
extern const int COLOR_global_compiler__GlobalCompiler__generate_init_instance;
extern const int COLOR_abstract_compiler__AbstractCompiler__generate_check_init_instance;
extern const int COLOR_global_compiler__GlobalCompiler__generate_box_instance;
extern const int COLOR_abstract_compiler__AbstractCompiler__compile_main_function;
extern const int COLOR_global_compiler__GlobalCompiler__todos;
extern const int COLOR_abstract_collection__Collection__is_empty;
extern const int COLOR_abstract_collection__Sequence__shift;
extern const int COLOR_global_compiler__GlobalCompiler__seen;
extern const int COLOR_abstract_collection__Collection__length;
val* NEW_array__Array(const struct type* type);
extern const struct type type_array__Arraykernel__Object;
val* NEW_array__NativeArray(int length, const struct type* type);
extern const struct type type_array__NativeArraykernel__Object;
extern const int COLOR_array__Array__with_native;
void CHECK_NEW_array__Array(val*);
extern const int COLOR_string__Object__to_s;
extern const int COLOR_abstract_compiler__AbstractRuntimeFunction__compile_to_c;
extern const int COLOR_abstract_compiler__AbstractCompiler__display_stats;
extern const int COLOR_abstract_compiler__ModelBuilder__write_and_make;
void global_compiler__ModelBuilder__run_global_compiler(val* self, val* p0, val* p1);
extern const int COLOR_global_compiler__GlobalCompiler___64druntime_type_analysis;
val* global_compiler__GlobalCompiler__runtime_type_analysis(val* self);
void global_compiler__GlobalCompiler__runtime_type_analysis_61d(val* self, val* p0);
extern const int COLOR_abstract_compiler__AbstractCompiler__init;
extern const int COLOR_model_base__MModule__name;
extern const int COLOR_abstract_compiler__AbstractCompiler__new_file;
val* NEW_abstract_compiler__CodeWriter(const struct type* type);
extern const struct type type_abstract_compiler__CodeWriter;
extern const int COLOR_abstract_compiler__CodeWriter__init;
void CHECK_NEW_abstract_compiler__CodeWriter(val*);
extern const int COLOR_abstract_compiler__AbstractCompiler__header_61d;
extern const int COLOR_global_compiler__GlobalCompiler__runtime_type_analysis_61d;
extern const struct type type_array__Arraymodel__MClassType;
extern const int COLOR_array__Array__init;
extern const int COLOR_global_compiler__GlobalCompiler__live_primitive_types_61d;
extern const int COLOR_kernel__Object___33d_61d;
extern const int COLOR_global_compiler__GlobalCompiler__live_primitive_types;
extern const int COLOR_abstract_collection__SimpleCollection__add;
void global_compiler__GlobalCompiler__init(val* self, val* p0, val* p1, val* p2);
extern const int COLOR_abstract_compiler__AbstractCompiler__new_visitor;
extern const int COLOR_abstract_compiler__AbstractCompiler__header;
extern const int COLOR_abstract_compiler__CodeWriter__add_decl;
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__add;
extern const int COLOR_global_compiler__GlobalCompiler__runtime_type_analysis;
extern const int COLOR_global_compiler__GlobalCompiler__classid;
void global_compiler__GlobalCompiler__compile_class_names(val* self);
extern const int COLOR_global_compiler__GlobalCompiler__classids;
extern const int COLOR_abstract_collection__MapRead__has_key;
extern const int COLOR_abstract_collection__MapRead___91d_93d;
extern const int COLOR_file__Object__print;
val* global_compiler__GlobalCompiler__classid(val* self, val* p0);
extern const int COLOR_global_compiler__GlobalCompiler___64dclassids;
val* global_compiler__GlobalCompiler__classids(val* self);
void global_compiler__GlobalCompiler__classids_61d(val* self, val* p0);
void global_compiler__GlobalCompiler__compile_header_structs(val* self);
extern const int COLOR_global_compiler__GlobalCompiler___64dlive_primitive_types;
val* global_compiler__GlobalCompiler__live_primitive_types(val* self);
void global_compiler__GlobalCompiler__live_primitive_types_61d(val* self, val* p0);
extern const int COLOR_abstract_collection__Collection__has;
void global_compiler__GlobalCompiler__todo(val* self, val* p0);
extern const int COLOR_global_compiler__GlobalCompiler___64dtodos;
val* global_compiler__GlobalCompiler__todos(val* self);
void global_compiler__GlobalCompiler__todos_61d(val* self, val* p0);
extern const int COLOR_global_compiler__GlobalCompiler___64dseen;
val* global_compiler__GlobalCompiler__seen(val* self);
void global_compiler__GlobalCompiler__seen_61d(val* self, val* p0);
extern const int COLOR_abstract_collection__MapRead__length;
extern const int COLOR_abstract_compiler__MType__c_name;
extern const int COLOR_string__String___43d;
extern const int COLOR_abstract_collection__Map___91d_93d_61d;
extern const int COLOR_model__MClassType__mclass;
extern const int COLOR_model__MClass__name;
extern const int COLOR_model__MClassType__arguments;
extern const int COLOR_abstract_collection__Collection__first;
extern const int COLOR_abstract_compiler__AbstractCompiler__mainmodule;
extern const int COLOR_model__MType__collect_mclassdefs;
extern const int COLOR_model__MClassDef__intro_mproperties;
extern const struct type type_model__MAttribute;
extern const int COLOR_model__MProperty__intro;
extern const int COLOR_model__MAttributeDef__static_mtype;
extern const int COLOR_model__MType__anchor_to;
extern const int COLOR_abstract_compiler__MPropDef__c_name;
void global_compiler__GlobalCompiler__declare_runtimeclass(val* self, val* p0);
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__add_decl;
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__new_var;
extern const int COLOR_abstract_compiler__RuntimeVariable__is_exact_61d;
extern const int COLOR_abstract_compiler__AbstractCompiler__generate_init_attr;
void global_compiler__GlobalCompiler__generate_init_instance(val* self, val* p0);
extern const int COLOR_abstract_compiler__AbstractCompiler__modelbuilder;
extern const int COLOR_abstract_compiler__ToolContext__opt_no_check_initialization;
extern const int COLOR_opts__Option__value;
val* NEW_abstract_compiler__RuntimeVariable(const struct type* type);
extern const struct type type_abstract_compiler__RuntimeVariable;
extern const int COLOR_abstract_compiler__RuntimeVariable__init;
void CHECK_NEW_abstract_compiler__RuntimeVariable(val*);
extern const int COLOR_abstract_compiler__AbstractCompiler__generate_check_attr;
void global_compiler__GlobalCompiler__generate_check_init_instance(val* self, val* p0);
void global_compiler__GlobalCompiler__generate_box_instance(val* self, val* p0);
val* NEW_global_compiler__GlobalCompilerVisitor(const struct type* type);
extern const struct type type_global_compiler__GlobalCompilerVisitor;
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__init;
void CHECK_NEW_global_compiler__GlobalCompilerVisitor(val*);
extern const int COLOR_abstract_compiler__AbstractCompiler_VTVISITOR;
val* global_compiler__GlobalCompiler__new_visitor(val* self);
extern const int COLOR_global_compiler__GlobalCompiler___64dcollect_types_cache;
val* global_compiler__GlobalCompiler__collect_types_cache(val* self);
void global_compiler__GlobalCompiler__collect_types_cache_61d(val* self, val* p0);
extern const int COLOR_abstract_compiler__RuntimeVariable__mtype;
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__new_expr;
extern const struct type type_model__MClassType;
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__compiler;
val* global_compiler__GlobalCompilerVisitor__autobox(val* self, val* p0, val* p1);
extern const int COLOR_abstract_compiler__RuntimeVariable__mcasttype;
extern const int COLOR_abstract_compiler__RuntimeVariable__is_exact;
extern const int COLOR_array__Array__with_capacity;
extern const int COLOR_abstract_collection__Sequence__push;
extern const int COLOR_global_compiler__GlobalCompiler__collect_types_cache;
extern const int COLOR_model__MType__is_subtype;
val* global_compiler__GlobalCompilerVisitor__collect_types(val* self, val* p0);
extern const int COLOR_abstract_collection__SequenceRead___91d_93d;
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__ret;
void global_compiler__GlobalCompilerVisitor__native_array_def(val* self, val* p0, val* p1, val* p2);
void global_compiler__GlobalCompilerVisitor__calloc_array(val* self, val* p0, val* p1);
extern const int COLOR_global_compiler__GlobalCompilerVisitor__collect_types;
extern const int COLOR_model__MMethodDef__msignature;
extern const int COLOR_model__MSignature__return_mtype;
extern const int COLOR_model__MMethod__is_new;
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__resolve_for;
extern const int COLOR_string__Object__inspect;
extern const int COLOR_model__MProperty__lookup_first_definition;
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__call;
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__assign;
extern const int COLOR_abstract_compiler__ToolContext__opt_no_check_other;
extern const int COLOR_model__MProperty__name;
extern const struct type type_model__MNullableType;
extern const struct type type_model__MNullType;
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__add_abort;
extern const int COLOR_global_compiler__GlobalCompilerVisitor__bugtype;
extern const int COLOR_abstract_collection__SequenceRead__last;
extern const int COLOR_model__MPropDef__mclassdef;
extern const int COLOR_model__MClassDef__mclass;
extern const int COLOR_abstract_compiler__AbstractCompiler__hardening;
extern const int COLOR_model__MClassDef__bound_mtype;
val* global_compiler__GlobalCompilerVisitor__send(val* self, val* p0, val* p1);
void global_compiler__GlobalCompilerVisitor__check_valid_reciever(val* self, val* p0);
extern const int COLOR_global_compiler__GlobalCompilerVisitor__check_valid_reciever;
val* global_compiler__GlobalCompilerVisitor__get_recvtype(val* self, val* p0, val* p1, val* p2);
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__autobox;
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__autoadapt;
val* global_compiler__GlobalCompilerVisitor__get_recv(val* self, val* p0, val* p1);
extern const int COLOR_model__MSignature__arity;
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__debug;
val* NEW_global_compiler__CustomizedRuntimeFunction(const struct type* type);
extern const struct type type_global_compiler__CustomizedRuntimeFunction;
extern const int COLOR_global_compiler__CustomizedRuntimeFunction__init;
void CHECK_NEW_global_compiler__CustomizedRuntimeFunction(val*);
extern const int COLOR_abstract_compiler__AbstractRuntimeFunction__call;
val* global_compiler__GlobalCompilerVisitor__finalize_call(val* self, val* p0, val* p1, val* p2);
extern const int COLOR_global_compiler__GlobalCompilerVisitor__get_recvtype;
extern const int COLOR_global_compiler__GlobalCompilerVisitor__get_recv;
extern const int COLOR_array__Collection__to_a;
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__varargize;
extern const int COLOR_abstract_collection__Sequence__first_61d;
extern const int COLOR_global_compiler__GlobalCompilerVisitor__finalize_call;
val* global_compiler__GlobalCompilerVisitor__call(val* self, val* p0, val* p1, val* p2);
val* global_compiler__GlobalCompilerVisitor__call_without_varargize(val* self, val* p0, val* p1, val* p2);
extern const int COLOR_model__MPropDef__mproperty;
extern const int COLOR_model__MPropDef__lookup_next_definition;
extern const int COLOR_global_compiler__GlobalCompilerVisitor__call_without_varargize;
val* global_compiler__GlobalCompilerVisitor__supercall(val* self, val* p0, val* p1, val* p2);
val* NEW_range__Range(const struct type* type);
extern const struct type type_range__Rangekernel__Int;
extern const int COLOR_range__Range__without_last;
void CHECK_NEW_range__Range(val*);
extern const int COLOR_model__MSignature__mparameters;
extern const int COLOR_model__MParameter__mtype;
extern const int COLOR_model__MSignature__vararg_rank;
extern const int COLOR_abstract_collection__Sequence___91d_93d_61d;
void global_compiler__GlobalCompilerVisitor__adapt_signature(val* self, val* p0, val* p1);
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__array_instance;
val* global_compiler__GlobalCompilerVisitor__vararg_instance(val* self, val* p0, val* p1, val* p2, val* p3);
void global_compiler__GlobalCompilerVisitor__bugtype(val* self, val* p0);
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__check_recv_notnull;
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__bool_type;
val* global_compiler__GlobalCompilerVisitor__isset_attribute(val* self, val* p0, val* p1);
val* global_compiler__GlobalCompilerVisitor__read_attribute(val* self, val* p0, val* p1);
void global_compiler__GlobalCompilerVisitor__write_attribute(val* self, val* p0, val* p1, val* p2);
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__anchor;
val* global_compiler__GlobalCompilerVisitor__init_instance(val* self, val* p0);
extern const int COLOR_model__MNullableType__mtype;
extern const int COLOR_rapid_type_analysis__RapidTypeAnalysis__live_cast_types;
val* global_compiler__GlobalCompilerVisitor__type_test(val* self, val* p0, val* p1, val* p2);
val* global_compiler__GlobalCompilerVisitor__is_same_type_test(val* self, val* p0, val* p1);
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__get_name;
val* global_compiler__GlobalCompilerVisitor__class_name_string(val* self, val* p0);
extern const struct type type_array__Arraystring__String;
extern const int COLOR_string__Collection__join;
val* global_compiler__GlobalCompilerVisitor__equal_test(val* self, val* p0, val* p1);
void global_compiler__GlobalCompilerVisitor__check_init_instance(val* self, val* p0, val* p1);
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__get_class;
extern const struct type type_array__Arraymodel__MType;
extern const struct type type_array__NativeArraymodel__MType;
extern const int COLOR_model__MClass__get_mtype;
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__init_instance;
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__int_instance;
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__get_property;
extern const struct type type_array__Arrayabstract_compiler__RuntimeVariable;
extern const struct type type_array__NativeArrayabstract_compiler__RuntimeVariable;
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__send;
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__check_init_instance;
val* global_compiler__GlobalCompilerVisitor__array_instance(val* self, val* p0, val* p1);
extern const int COLOR_global_compiler__CustomizedRuntimeFunction___64drecv;
val* global_compiler__CustomizedRuntimeFunction__recv(val* self);
void global_compiler__CustomizedRuntimeFunction__recv_61d(val* self, val* p0);
extern const int COLOR_abstract_compiler__AbstractRuntimeFunction__init;
extern const int COLOR_global_compiler__CustomizedRuntimeFunction__recv_61d;
void global_compiler__CustomizedRuntimeFunction__init(val* self, val* p0, val* p1);
extern const int COLOR_abstract_compiler__AbstractRuntimeFunction__c_name_cache;
extern const int COLOR_abstract_compiler__AbstractRuntimeFunction__mmethoddef;
extern const int COLOR_global_compiler__CustomizedRuntimeFunction__recv;
extern const int COLOR_abstract_compiler__AbstractRuntimeFunction__c_name_cache_61d;
val* global_compiler__CustomizedRuntimeFunction__build_c_name(val* self);
short int global_compiler__CustomizedRuntimeFunction___61d_61d(val* self, val* p0);
extern const int COLOR_kernel__Object__hash;
long global_compiler__CustomizedRuntimeFunction__hash(val* self);
val* global_compiler__CustomizedRuntimeFunction__to_s(val* self);
extern const int COLOR_abstract_compiler__AbstractRuntimeFunction_VTCOMPILER;
val* NEW_abstract_compiler__Frame(const struct type* type);
extern const struct type type_abstract_compiler__Frame;
extern const int COLOR_abstract_compiler__Frame__init;
void CHECK_NEW_abstract_compiler__Frame(val*);
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__frame_61d;
val* NEW_string__Buffer(const struct type* type);
extern const struct type type_string__Buffer;
extern const int COLOR_string__Buffer__init;
void CHECK_NEW_string__Buffer(val*);
extern const int COLOR_abstract_collection__Sequence__append;
extern const int COLOR_abstract_compiler__AbstractRuntimeFunction__c_name;
extern const int COLOR_abstract_compiler__Frame__returnvar_61d;
extern const int COLOR_abstract_compiler__Frame__returnlabel_61d;
extern const int COLOR_abstract_compiler__MMethodDef__compile_inside_to_c;
extern const int COLOR_abstract_compiler__Frame__returnlabel;
extern const int COLOR_abstract_compiler__Frame__returnvar;
void global_compiler__CustomizedRuntimeFunction__compile_to_c(val* self, val* p0);
extern const int COLOR_abstract_compiler__AbstractRuntimeFunction_VTVISITOR;
extern const int COLOR_abstract_compiler__MMethodDef__can_inline;
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__frame;
extern const int COLOR_abstract_compiler__AbstractCompilerVisitor__adapt_signature;
extern const int COLOR_global_compiler__GlobalCompiler__todo;
val* global_compiler__CustomizedRuntimeFunction__call(val* self, val* p0, val* p1);
