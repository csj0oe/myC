%code requires{
#include "Table_des_symboles.h"
#include "Attribute.h"
}

%{

#include <stdio.h>
#include <string.h>

FILE * filec;
FILE * fileh;

extern int yylex();
extern int yyparse();

void yyerror (char* s) {
  printf ("%s\n",s);
}

%}

%union {
	attribute val;
	char* str;
	type typ;
	int num;
}
%token <val> NUMI NUMF
%token <val> ID
%token TINT TFLOAT STRUCT
%token AO AF PO PF PV VIR
%token RETURN VOID EQ
%token <val> IF ELSE WHILE

%token <val> AND OR NOT DIFF EQUAL SUP INF
%token PLUS MOINS STAR DIV
%token DOT ARR

%type <val> exp type vir fun_id app
%type <str> vlist
%type <typ> typename
%type <num> while_cond while bool_cond else pointer

%left DIFF EQUAL SUP INF       // low priority on comparison
%left PLUS MOINS               // higher priority on + -
%left STAR DIV                 // higher priority on * /
%left OR                       // higher priority on ||
%left AND                      // higher priority on &&
%left DOT ARR                  // higher priority on . and ->
%nonassoc UNA                  // highest priority on unary operator

%start prog

%%

prog : block                   { ; }
;


oblock: AO                     { enter_block(); }
;

fblock: AF                     { exit_block(); }
;

block:
decl_list inst_list            { ; }
;

// I. Declarations

decl_list : decl decl_list     { ; }
|                              { ; }
;

decl: var_decl PV              { ; }
| struct_decl PV               {}
| fun_decl                     {}
;

// I.1. Variables
var_decl : type vlist          { /* FOR DEBUG */ fprintf(filec, "// %s(%d) %s;\n",print_type($1->type_val),$1->num_star,$2); }
;

// I.2. Structures
struct_decl : STRUCT ID struct {}
;

struct : AO attr AF            {}
;

attr : type ID                 {}
| type ID PV attr              {}

// I.3. Functions

fun_decl :
type fun_head fun_body         { ; }
;


fun_head : fun_id PO PF            { $1->type_val = $<val>0->type_val;
                                     set_symbol_value($1->name,$1);
                                   }
| fun_id PO params PF              { $1->type_val = $<val>0->type_val;
                                     set_symbol_value($1->name,$1);
                                   }
;

fun_id : ID                         { $1->num_label = new_label();
                                      fprintf(filec,"label%d:\n",$1->num_label);
                                      $$ = $1;
                                    }
;

params: type ID vir params     { if (exist_symbol_value($2->name)) print_error("already declared");
                                 $2->type_val = ($1->type_val);
                                 $2->num_star = ($1->num_star);
                                 $2->num_block = curr_block();
                                 fprintf(fileh,"%s %s%s;\n",print_type($2->type_val),print_star($2->num_star),$2->name);
                                 $2->reg_num = new_register($2);
                                 //fprintf(filec,"dep(r%d);\n",$2->reg_num);
                                 fprintf(filec,"%s = r%d;\n",$2->name,$2->reg_num);
                                 set_symbol_value($2->name,$2);
                                 /* FOR DEBUG */ //$$ = $2->name;
                                 }
| type ID                      { if (exist_symbol_value($2->name)) print_error("already declared");
                                 $2->type_val = ($1->type_val);
                                 $2->num_star = ($1->num_star);
                                 $2->num_block = curr_block();
                                 fprintf(fileh,"%s %s%s;\n",print_type($2->type_val),print_star($2->num_star),$2->name);
                                 $2->reg_num = new_register($2);
                                 //fprintf(filec,"dep(r%d);\n",$2->reg_num);
                                 fprintf(filec,"%s = r%d;\n",$2->name,$2->reg_num);
                                 set_symbol_value($2->name,$2);
                                 /* FOR DEBUG */ //$$ = $2->name;
                                 }

vlist: ID vir vlist            { if (exist_symbol_value($1->name)) print_error("already declared");
                                 $1->type_val = ($<val>0->type_val);
                                 $1->num_star = ($<val>0->num_star);
                                 $1->num_block = curr_block();
                                 fprintf(fileh,"%s %s%s;\n",print_type($1->type_val),print_star($1->num_star),$1->name);
                                 set_symbol_value($1->name,$1);
                                 /* FOR DEBUG */  $$ = str_concat($1->name,str_concat(",",$3)); }
| ID                           { if (exist_symbol_value($1->name)) print_error("already declared");
                                 $1->type_val = ($<val>0->type_val);
                                 $1->num_star = ($<val>0->num_star);
                                 $1->num_block = curr_block();
                                 fprintf(fileh,"%s %s%s;\n",print_type($1->type_val),print_star($1->num_star),$1->name);
                                 set_symbol_value($1->name,$1);
                                 /* FOR DEBUG */ $$ = $1->name; }
;

vir : VIR                      { attribute x = copy_attribute($<val>-1); x->num_star=0; $$ = x;}

fun_body :
oblock block fblock           { fprintf(filec,"goto *retReg;\n"); }
;

// I.4. Types
type
: typename pointer             { attribute x = new_attribute();
                                 x->type_val = $1;
                                 x->num_star = $2;
                                 $$ = x;
                               }
| typename                     { attribute x = new_attribute();
                                 x->type_val = $1;
                                 x->num_star = 0;
                                 $$ = x; }
;

typename
: TINT                          { $$ = INT; }
| TFLOAT                        { $$ = FLOAT; }
| VOID                          { $$ = VOD; }
| STRUCT ID                     { $$ = STRCT; }
;

pointer
: pointer STAR                 { $$ = $1 + 1; }
| STAR                         { $$ = 1; }
;


// II. Intructions

inst_list: inst inst_list   {}
//| inst                      { ; }
|                           { ; }
;

inst:
oblock block fblock           { ; }
| aff PV                      { ; }
| ret PV                      { ; }
| cond                        { ; }
| loop                        { ; }
| app PV                      { ; }
;

// II.1 Affectations

aff : ID EQ exp               { attribute x = get_symbol_value($1->name);
                                if (type_compatible(x,$3) ) fprintf(filec, "%s = r%d;\n",x->name,$3->reg_num);
                                else if(x->type_val == FLOAT && $3->type_val == INT) fprintf(filec, "%s = (float)r%d;\n",x->name,$3->reg_num);
                                else  print_error("non compatible types");
                                /* FOR DEBUG */ fprintf(filec, "// %s = %s;\n",x->name,$3->name);
                              }
| STAR exp EQ exp             { if (!type_compatible($2,$4)) print_error("non compatible types");
                                fprintf(filec, "*r%d = r%d;\n",$2->reg_num,$4->reg_num);
                              }
;


// II.2 Return
ret : RETURN exp              { //fprintf(filec,"enp(r%d);\n",$2->reg_num);
                              }
| RETURN PO PF                { ; } // ERROR ??? RETURN PO exp PF
;

// II.3. Conditionelles
cond :
if bool_cond inst else inst   { fprintf(filec,"label%d:\n",$4); } //inst <=> stat
|  if bool_cond inst          { fprintf(filec,"label%d:\n",$2); }
;

bool_cond : PO exp PF         { int x = new_label();
                                fprintf(filec,"if (!r%d) goto label%d;\n",$2->reg_num,x);
                                $$ = x; }
;

if : IF                       {}
;

else : ELSE                   { int x = new_label();
                                fprintf(filec,"goto label%d;\nlabel%d:\n",x,$<num>-1);
                                $$ = x; }
;

// II.4. Iterations

loop : while while_cond inst  { fprintf(filec,"goto label%d;\nlabel%d:\n",$1,$2); }
;

while_cond : PO exp PF        { int x = new_label();
                                fprintf(filec,"if (!r%d) goto label%d;\n",$2->reg_num,x);
                                $$=x; }

while : WHILE                 { int x = new_label();
                                fprintf(filec,"label%d:\n",x);
                                $$=x; }
;


// II.3 Expressions
exp
// II.3.0 Exp. arithmetiques
: MOINS exp %prec UNA         { attribute x = new_attribute();
                                x->type_val = $2->type_val;
                                x->reg_num = new_register(x);
                                fprintf(filec,"r%d = - r%d;\n",x->reg_num,$2->reg_num);
                                $$ = x; }
| exp PLUS exp                { attribute x = eval_exp($1,"+",$3);
                                $$ = x; }
| exp MOINS exp               { attribute x = eval_exp($1,"-",$3);
                                $$ = x; }
| exp STAR exp                { attribute x = eval_exp($1,"*",$3);
                                $$ = x; }
| exp DIV exp                 {attribute x = eval_exp($1,"/",$3);
                                $$ = x;}
| PO exp PF                   { $$ = $2; }
| ID                          { attribute x = get_symbol_value($1->name);
                                if (!in_block(x)) print_error("not declared (not in scope)\n");
                                x->reg_num = new_register(x);
                                fprintf(filec,"r%d = %s;\n",x->reg_num,x->name);
                                $$ = x; }
| NUMI                        { $1->reg_num = new_register($1); fprintf(filec,"r%d = %s;\n",$1->reg_num,$1->name); $$ = $1; }
| NUMF                        { $1->reg_num = new_register($1); fprintf(filec,"r%d = %s;\n",$1->reg_num,$1->name); $$ = $1; }

// II.3.1 Déréférencement

| STAR exp %prec UNA          { attribute x = copy_attribute($2);
                                x->num_star--;
                                x->reg_num = new_register(x);
                                fprintf(filec,"r%d = *r%d;\n",x->reg_num,$2->reg_num);
                                $$ = x;
                              }

// II.3.2. Booléens

| NOT exp %prec UNA           {}
| exp INF exp                 { if ($1->type_val != $3->type_val) print_error("non compatible types");
                                attribute x = new_attribute();
                                x->type_val = $1->type_val;
                                x->reg_num = new_register(x);
                                fprintf(filec,"r%d = r%d < r%d;\n",x->reg_num,$1->reg_num,$3->reg_num);
                                $$ = x; }
| exp SUP exp                 { if ($1->type_val != $3->type_val) print_error("non compatible types");
                                attribute x = new_attribute();
                                x->type_val = $1->type_val;
                                x->reg_num = new_register(x);
                                fprintf(filec,"r%d = r%d > r%d;\n",x->reg_num,$1->reg_num,$3->reg_num);
                                $$ = x; } 
| exp EQUAL exp               { if ($1->type_val != $3->type_val) print_error("non compatible types");
                                attribute x = new_attribute();
                                x->type_val = $1->type_val;
                                x->reg_num = new_register(x);
                                fprintf(filec,"r%d = r%d == r%d;\n",x->reg_num,$1->reg_num,$3->reg_num);
                                $$ = x; } 
| exp DIFF exp                { if ($1->type_val != $3->type_val) print_error("non compatible types");
                                attribute x = new_attribute();
                                x->type_val = $1->type_val;
                                x->reg_num = new_register(x);
                                fprintf(filec,"r%d = r%d != r%d;\n",x->reg_num,$1->reg_num,$3->reg_num);
                                $$ = x; } 
| exp AND exp                 { if ($1->type_val != $3->type_val) print_error("non compatible types");
                                attribute x = new_attribute();
                                x->type_val = $1->type_val;
                                x->reg_num = new_register(x);
                                fprintf(filec,"r%d = r%d & r%d;\n",x->reg_num,$1->reg_num,$3->reg_num);
                                $$ = x; } 
| exp OR exp                  { if ($1->type_val != $3->type_val) print_error("non compatible types");
                                attribute x = new_attribute();
                                x->type_val = $1->type_val;
                                x->reg_num = new_register(x);
                                fprintf(filec,"r%d = r%d | r%d;\n",x->reg_num,$1->reg_num,$3->reg_num);
                                $$ = x; } 

// II.3.3. Structures

| exp ARR ID                  {}
| exp DOT ID                  {}

| app                         {}
;

// II.4 Applications de fonctions

app : ID PO args PF           { attribute x =  get_symbol_value($1->name);
                                //if func snn error
                                int l = new_label();
                                fprintf(filec,"retReg = &&label%d;\n", l);
                                fprintf(filec,"goto label%d;\n", x->num_label);
                                fprintf(filec,"label%d:\n", l);
                                if (x->type_val != VOD) {
                                  attribute r = new_attribute();
                                  r->type_val = x->type_val;
                                  r->reg_num = new_register(x);
                                  //fprintf(filec,"dep(r%d);\n", r->reg_num);
                                  $$ = r;
                                }
                                $$ = NULL;
                              }
;

args :  arglist               { ; }
|                             { ; }
;

arglist : exp VIR arglist     { //fprintf(filec,"enp(r%d);\n", $1->reg_num);
}
| exp                         { //fprintf(filec,"enp(r%d);\n", $1->reg_num); 
}
;



%%



//int main () { printf ("? "); return yyparse ();}
int main (int argc, char* argv[]) {

  filec = fopen (argv[2], "w");
  fileh = fopen (argv[1], "w");

  fprintf(fileh, "#ifndef FILE_H\n");
  fprintf(fileh, "#define FILE_H\n");
  fprintf(fileh, "#include <stdio.h>\n");
  fprintf(fileh, "#include <stdlib.h>\n");
  fprintf(fileh, "#include <string.h>\n");
  fprintf(fileh, "int* retReg;\n");


  fprintf(filec, "#include \"../%s\"\n",argv[1]);
  fprintf(filec, "int main() {\n");

  yyparse ();

  fprintf(fileh, "#endif\n");
  fprintf(filec, "return 0; }\n");

  return 0;

}