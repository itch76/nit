/* This C header file is generated by NIT to compile modules and programs that requires ./global/reachable_as_init_impl. */
#ifndef global___reachable_as_init_impl_sep
#define global___reachable_as_init_impl_sep
#include "global___reachable_method_analysis._sep.h"
#include "global___reachable_as_init._sep.h"
#include <nit_common.h>

extern const classtable_elt_t VFT_global___reachable_as_init_impl___ReachableAsInitBuilder[];

extern const classtable_elt_t VFT_global___reachable_as_init_impl___ReachableAsInitAnalysisImpl[];

extern const classtable_elt_t VFT_global___reachable_as_init_impl___RAIVisitor[];
extern const char LOCATE_global___reachable_as_init_impl[];
extern const int SFT_global___reachable_as_init_impl[];
#define ID_global___reachable_as_init_impl___ReachableAsInitBuilder (SFT_global___reachable_as_init_impl[0])
#define COLOR_global___reachable_as_init_impl___ReachableAsInitBuilder (SFT_global___reachable_as_init_impl[1])
#define ATTR_global___reachable_as_init_impl___ReachableAsInitBuilder____context(recv) ATTR(recv, (SFT_global___reachable_as_init_impl[2] + 0))
#define ATTR_global___reachable_as_init_impl___ReachableAsInitBuilder____program(recv) ATTR(recv, (SFT_global___reachable_as_init_impl[2] + 1))
#define INIT_TABLE_POS_global___reachable_as_init_impl___ReachableAsInitBuilder (SFT_global___reachable_as_init_impl[3] + 0)
#define CALL_global___reachable_as_init_impl___ReachableAsInitBuilder___context(recv) ((global___reachable_as_init_impl___ReachableAsInitBuilder___context_t)CALL((recv), (SFT_global___reachable_as_init_impl[3] + 1)))
#define CALL_global___reachable_as_init_impl___ReachableAsInitBuilder___program(recv) ((global___reachable_as_init_impl___ReachableAsInitBuilder___program_t)CALL((recv), (SFT_global___reachable_as_init_impl[3] + 2)))
#define CALL_global___reachable_as_init_impl___ReachableAsInitBuilder___work(recv) ((global___reachable_as_init_impl___ReachableAsInitBuilder___work_t)CALL((recv), (SFT_global___reachable_as_init_impl[3] + 3)))
#define CALL_global___reachable_as_init_impl___ReachableAsInitBuilder___init(recv) ((global___reachable_as_init_impl___ReachableAsInitBuilder___init_t)CALL((recv), (SFT_global___reachable_as_init_impl[3] + 4)))
#define ID_global___reachable_as_init_impl___ReachableAsInitAnalysisImpl (SFT_global___reachable_as_init_impl[4])
#define COLOR_global___reachable_as_init_impl___ReachableAsInitAnalysisImpl (SFT_global___reachable_as_init_impl[5])
#define ATTR_global___reachable_as_init_impl___ReachableAsInitAnalysisImpl____methods(recv) ATTR(recv, (SFT_global___reachable_as_init_impl[6] + 0))
#define INIT_TABLE_POS_global___reachable_as_init_impl___ReachableAsInitAnalysisImpl (SFT_global___reachable_as_init_impl[7] + 0)
#define CALL_global___reachable_as_init_impl___ReachableAsInitAnalysisImpl___init(recv) ((global___reachable_as_init_impl___ReachableAsInitAnalysisImpl___init_t)CALL((recv), (SFT_global___reachable_as_init_impl[7] + 1)))
#define ID_global___reachable_as_init_impl___RAIVisitor (SFT_global___reachable_as_init_impl[8])
#define COLOR_global___reachable_as_init_impl___RAIVisitor (SFT_global___reachable_as_init_impl[9])
#define ATTR_global___reachable_as_init_impl___RAIVisitor____builder(recv) ATTR(recv, (SFT_global___reachable_as_init_impl[10] + 0))
#define INIT_TABLE_POS_global___reachable_as_init_impl___RAIVisitor (SFT_global___reachable_as_init_impl[11] + 0)
#define CALL_global___reachable_as_init_impl___RAIVisitor___builder(recv) ((global___reachable_as_init_impl___RAIVisitor___builder_t)CALL((recv), (SFT_global___reachable_as_init_impl[11] + 1)))
#define CALL_SUPER_global___reachable_as_init_impl___RAIVisitor___visit_icode(recv) ((global___reachable_as_init_impl___RAIVisitor___visit_icode_t)CALL((recv), (SFT_global___reachable_as_init_impl[11] + 2)))
#define CALL_global___reachable_as_init_impl___RAIVisitor___init(recv) ((global___reachable_as_init_impl___RAIVisitor___init_t)CALL((recv), (SFT_global___reachable_as_init_impl[11] + 3)))
val_t global___reachable_as_init_impl___ReachableAsInitBuilder___context(val_t p0);
typedef val_t (*global___reachable_as_init_impl___ReachableAsInitBuilder___context_t)(val_t p0);
val_t global___reachable_as_init_impl___ReachableAsInitBuilder___program(val_t p0);
typedef val_t (*global___reachable_as_init_impl___ReachableAsInitBuilder___program_t)(val_t p0);
void global___reachable_as_init_impl___ReachableAsInitBuilder___work(val_t p0);
typedef void (*global___reachable_as_init_impl___ReachableAsInitBuilder___work_t)(val_t p0);
  void OC_global___reachable_as_init_impl___ReachableAsInitBuilder___work_1(struct stack_frame_t *closctx, val_t p0, val_t p1);
  typedef void (*OC_global___reachable_as_init_impl___ReachableAsInitBuilder___work_1_t)(struct stack_frame_t *closctx, val_t p0, val_t p1);
void global___reachable_as_init_impl___ReachableAsInitBuilder___init(val_t p0, val_t p1, int* init_table);
typedef void (*global___reachable_as_init_impl___ReachableAsInitBuilder___init_t)(val_t p0, val_t p1, int* init_table);
val_t NEW_ReachableAsInitBuilder_global___reachable_as_init_impl___ReachableAsInitBuilder___init(val_t p0);
val_t global___reachable_as_init_impl___ReachableAsInitAnalysisImpl___is_method_reachable_as_init(val_t p0, val_t p1, val_t p2);
typedef val_t (*global___reachable_as_init_impl___ReachableAsInitAnalysisImpl___is_method_reachable_as_init_t)(val_t p0, val_t p1, val_t p2);
void global___reachable_as_init_impl___ReachableAsInitAnalysisImpl___init(val_t p0, int* init_table);
typedef void (*global___reachable_as_init_impl___ReachableAsInitAnalysisImpl___init_t)(val_t p0, int* init_table);
val_t NEW_ReachableAsInitAnalysisImpl_global___reachable_as_init_impl___ReachableAsInitAnalysisImpl___init();
val_t global___reachable_as_init_impl___RAIVisitor___builder(val_t p0);
typedef val_t (*global___reachable_as_init_impl___RAIVisitor___builder_t)(val_t p0);
void global___reachable_as_init_impl___RAIVisitor___visit_icode(val_t p0, val_t p1);
typedef void (*global___reachable_as_init_impl___RAIVisitor___visit_icode_t)(val_t p0, val_t p1);
void global___reachable_as_init_impl___RAIVisitor___init(val_t p0, val_t p1, int* init_table);
typedef void (*global___reachable_as_init_impl___RAIVisitor___init_t)(val_t p0, val_t p1, int* init_table);
val_t NEW_RAIVisitor_global___reachable_as_init_impl___RAIVisitor___init(val_t p0);
#endif