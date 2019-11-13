%code requires{
#include "Table_des_symboles.h"
#include "Attribute.h"
 }

%{

#include <stdio.h>
#include <string.h>
  
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

%type <val> exp
%type <str> vlist 
%type <typ> typename type vir

%left DIFF EQUAL SUP INF       // low priority on comparison
%left PLUS MOINS               // higher priority on + - 
%left STAR DIV                 // higher priority on * /
%left OR                       // higher priority on ||
%left AND                      // higher priority on &&
%left DOT ARR                  // higher priority on . and -> 
%nonassoc UNA                  // highest priority on unary operator
 
%start prog  

%%

prog : block                   {} // DONE
;

block:
decl_list inst_list            {} // DONE
;

// I. Declarations

decl_list : decl decl_list     {} // DONE
|                              {} // DONE
;

decl: var_decl PV              {} // DONE
| struct_decl PV               {}
| fun_decl                     {}
;

// I.1. Variables
var_decl : type vlist          { /* FOR DEBUG */ fprintf(stdout, "// %s %s;\n",print_type($1),$2); }
;

// I.2. Structures
struct_decl : STRUCT ID struct {}
;

struct : AO attr AF            {}
;

attr : type ID                 {}
| type ID PV attr              {}

// I.3. Functions

fun_decl : type fun            {}
;

fun : fun_head fun_body        {}
;

fun_head : ID PO PF            {}
| ID PO params PF              {}
;

params: type ID vir params     {}
| type ID                      {}

vlist: ID vir vlist            { $1->type_val = ($<typ>0); $1->reg_num = new_register($1->type_val);
                                 set_symbol_value($1->name,$1);
                                 /* FOR DEBUG */  $$ = str_concat($1->name,str_concat(",",$3)); }
| ID                           { $1->type_val = ($<typ>0); $1->reg_num = new_register($1->type_val);
                                 set_symbol_value($1->name,$1);
                                 /* FOR DEBUG */ $$ = $1->name; }
;

vir : VIR                      { $$ = $<typ>-1; }
;

fun_body : AO block AF         {}
;

// I.4. Types
type
: typename pointer             {}
| typename                     { $$ = $1; }
;

typename
: TINT                          { $$ = INT; }
| TFLOAT                        { $$ = FLOAT; }
| VOID                          { $$ = VOD; }
| STRUCT ID                     { $$ = STRCT; }
;

pointer
: pointer STAR                 {}
| STAR                         {}
;


// II. Intructions

inst_list: inst PV inst_list   {} // DONE
| inst                         {} // DONE
;

inst:
exp                           {} // ERROR ???
| AO block AF                 {}
| aff                         {} // DONE
| ret                         {} // DONE
| cond                        {}
| loop                        {}
| PV                          {}
;

// II.1 Affectations

aff : ID EQ exp               { attribute x = get_symbol_value($1->name);
                                if (x->type_val != $3->type_val) print_error("non compatible types");
                                fprintf(stdout, "r%d = r%d;\n",x->reg_num,$3->reg_num);
                                /* FOR DEBUG */ fprintf(stdout, "// %s = %s;\n",x->name,$3->name);
                              }
| ID STAR EQ exp              { attribute x = get_symbol_value($1->name);
                                if (x->type_val != $4->type_val) print_error("non compatible types");
                                fprintf(stdout, "r%d = r%d * r%d;\n",x->reg_num,x->reg_num,$4->reg_num);
                                /* FOR DEBUG */ fprintf(stdout, "// %s = %s;\n",x->name,$4->name); 
                              } // CHANGED ??? exp STAR EQ exp
;


// II.2 Return
ret : RETURN exp              {}
| RETURN PO exp PF            {} // CHANGED ??? RETURN PO PF
;

// II.3. Conditionelles
cond :
if bool_cond inst             {}
|  else inst                  {}
;


bool_cond : PO exp PF         {}
;

if : IF                       {}
;

else : ELSE                   {}
;

// II.4. Iterations

loop : while while_cond inst  {}
;

while_cond : PO exp PF        {}

while : WHILE                 {}
;


// II.3 Expressions
exp
// II.3.0 Exp. arithmetiques
: MOINS exp %prec UNA         { attribute x = new_attribute();
                                x->type_val = $2->type_val;
                                x->reg_num = new_register(x->type_val);
                                fprintf(stdout,"r%d = - r%d;\n",x->reg_num,$2->reg_num);
                                $$ = x; }
| exp PLUS exp                { if ($1->type_val != $3->type_val) print_error("non compatible types");
                                attribute x = new_attribute();
                                x->type_val = $1->type_val;
                                x->reg_num = new_register(x->type_val);
                                fprintf(stdout,"r%d = r%d + r%d;\n",x->reg_num,$1->reg_num,$3->reg_num);
                                $$ = x; }
| exp MOINS exp               { if ($1->type_val != $3->type_val) print_error("non compatible types");
                                attribute x = new_attribute();
                                x->type_val = $1->type_val;
                                x->reg_num = new_register(x->type_val);
                                fprintf(stdout,"r%d = r%d - r%d;\n",x->reg_num,$1->reg_num,$3->reg_num);
                                $$ = x; }
| exp STAR exp                { if ($1->type_val != $3->type_val) print_error("non compatible types");
                                attribute x = new_attribute();
                                x->type_val = $1->type_val;
                                x->reg_num = new_register(x->type_val);
                                fprintf(stdout,"r%d = r%d * r%d;\n",x->reg_num,$1->reg_num,$3->reg_num);
                                $$ = x; }
| exp DIV exp                 { if ($1->type_val != $3->type_val) print_error("non compatible types");
                                attribute x = new_attribute();
                                x->type_val = $1->type_val;
                                x->reg_num = new_register(x->type_val);
                                fprintf(stdout,"r%d = r%d / r%d;\n",x->reg_num,$1->reg_num,$3->reg_num);
                                $$ = x; }
| PO exp PF                   { $$ = $2; }
| ID                          { attribute x = get_symbol_value($1->name); $$ = x; }
| NUMI                        { $1->reg_num = new_register($1->type_val); fprintf(stdout,"r%d = %s;\n",$1->reg_num,$1->name); $$ = $1; }
| NUMF                        { $1->reg_num = new_register($1->type_val); fprintf(stdout,"r%d = %s;\n",$1->reg_num,$1->name); $$ = $1; }

// II.3.1 Déréférencement

| STAR exp %prec UNA          {}

// II.3.2. Booléens

| NOT exp %prec UNA           {}
| exp INF exp                 {}
| exp SUP exp                 {}
| exp EQUAL exp               {}
| exp DIFF exp                {}
| exp AND exp                 {}
| exp OR exp                  {}

// II.3.3. Structures

| exp ARR ID                  {}
| exp DOT ID                  {}

| app                         {}
;
       
// II.4 Applications de fonctions

app : ID PO args PF;

args :  arglist               {}
|                             {}
;

arglist : exp VIR arglist     {}
| exp                         {}
;



%% 

int main () { printf ("? "); return yyparse ();} 

