D                       [0-9]
L                       [a-zA-Z_]
H                       [a-fA-F0-9]
E                       ([Ee][+-]?{D}+)
P                       ([Pp][+-]?{D}+)
FS                      (f|F|l|L)
IS                      ((u|U)|(u|U)?(l|L|ll|LL)|(l|L|ll|LL)(u|U))

%{
#include <stdio.h>
#include <ctype.h>
#include <assert.h>
#include "c99.tab.h"

extern int lineno, column;
extern int error_count;

int is_typedefed(const char *text);
void add_typedef(const char *text);
void yyerror(const char *format, ...);

static int in_typedef = 0;
static int in_typedef_paren = 0;
static int in_func_typedef = 0;
static int in_func_typedef_body = 0;
static char *s_typedef_typename = NULL;

static void count(void);
static void comment(void);
static int check_type(void);
static void enter_paren(void);
static void leave_paren(void);
static void do_semicolon(void);
static void do_typedef(void);
static void do_asterisk(void);

%}

%option noyywrap

%%
"/*"                    { comment(); }
"//"[^\n]*              { /* consume //-comment */ }

"auto"                  { count(); return(AUTO); }
"_Bool"                 { count(); return(BOOL); }
"break"                 { count(); return(BREAK); }
"case"                  { count(); return(CASE); }
"char"                  { count(); return(CHAR); }
"_Complex"              { count(); return(COMPLEX); }
"const"                 { count(); return(CONST); }
"continue"              { count(); return(CONTINUE); }
"default"               { count(); return(DEFAULT); }
"do"                    { count(); return(DO); }
"double"                { count(); return(DOUBLE); }
"else"                  { count(); return(ELSE); }
"enum"                  { count(); return(ENUM); }
"extern"                { count(); return(EXTERN); }
"float"                 { count(); return(FLOAT); }
"for"                   { count(); return(FOR); }
"goto"                  { count(); return(GOTO); }
"if"                    { count(); return(IF); }
"_Imaginary"            { count(); return(IMAGINARY); }
"inline"                { count(); return(INLINE); }
"int"                   { count(); return(INT); }
"long"                  { count(); return(LONG); }
"register"              { count(); return(REGISTER); }
"restrict"              { count(); return(RESTRICT); }
"return"                { count(); return(RETURN); }
"short"                 { count(); return(SHORT); }
"signed"                { count(); return(SIGNED); }
"sizeof"                { count(); return(SIZEOF); }
"static"                { count(); return(STATIC); }
"struct"                { count(); return(STRUCT); }
"switch"                { count(); return(SWITCH); }
"typedef"               { count(); do_typedef(); return(TYPEDEF); }
"union"                 { count(); return(UNION); }
"unsigned"              { count(); return(UNSIGNED); }
"void"                  { count(); return(VOID); }
"volatile"              { count(); return(VOLATILE); }
"while"                 { count(); return(WHILE); }

{L}({L}|{D})*           { count(); return(check_type()); }

0[xX]{H}+{IS}?          { count(); return(CONSTANT); }
0[0-7]*{IS}?            { count(); return(CONSTANT); }
[1-9]{D}*{IS}?          { count(); return(CONSTANT); }
L?'(\\.|[^\\'\n])+'     { count(); return(CONSTANT); }

{D}+{E}{FS}?            { count(); return(CONSTANT); }
{D}*"."{D}+{E}?{FS}?    { count(); return(CONSTANT); }
{D}+"."{D}*{E}?{FS}?    { count(); return(CONSTANT); }
0[xX]{H}+{P}{FS}?       { count(); return(CONSTANT); }
0[xX]{H}*"."{H}+{P}?{FS}?     { count(); return(CONSTANT); }
0[xX]{H}+"."{H}*{P}?{FS}?     { count(); return(CONSTANT); }

L?\"(\\.|[^\\"\n])*\"   { count(); return(STRING_LITERAL); }

"..."                   { count(); return(ELLIPSIS); }
">>="                   { count(); return(RIGHT_ASSIGN); }
"<<="                   { count(); return(LEFT_ASSIGN); }
"+="                    { count(); return(ADD_ASSIGN); }
"-="                    { count(); return(SUB_ASSIGN); }
"*="                    { count(); return(MUL_ASSIGN); }
"/="                    { count(); return(DIV_ASSIGN); }
"%="                    { count(); return(MOD_ASSIGN); }
"&="                    { count(); return(AND_ASSIGN); }
"^="                    { count(); return(XOR_ASSIGN); }
"|="                    { count(); return(OR_ASSIGN); }
">>"                    { count(); return(RIGHT_OP); }
"<<"                    { count(); return(LEFT_OP); }
"++"                    { count(); return(INC_OP); }
"--"                    { count(); return(DEC_OP); }
"->"                    { count(); return(PTR_OP); }
"&&"                    { count(); return(AND_OP); }
"||"                    { count(); return(OR_OP); }
"<="                    { count(); return(LE_OP); }
">="                    { count(); return(GE_OP); }
"=="                    { count(); return(EQ_OP); }
"!="                    { count(); return(NE_OP); }
";"                     { count(); do_semicolon(); return(';'); }
("{"|"<%")              { count(); return('{'); }
("}"|"%>")              { count(); return('}'); }
","                     { count(); return(','); }
":"                     { count(); return(':'); }
"="                     { count(); return('='); }
"("                     { count(); enter_paren(); return('('); }
")"                     { count(); leave_paren(); return(')'); }
("["|"<:")              { count(); return('['); }
("]"|":>")              { count(); return(']'); }
"."                     { count(); return('.'); }
"&"                     { count(); return('&'); }
"!"                     { count(); return('!'); }
"~"                     { count(); return('~'); }
"-"                     { count(); return('-'); }
"+"                     { count(); return('+'); }
"*"                     { count(); do_asterisk(); return('*'); }
"/"                     { count(); return('/'); }
"%"                     { count(); return('%'); }
"<"                     { count(); return('<'); }
">"                     { count(); return('>'); }
"^"                     { count(); return('^'); }
"|"                     { count(); return('|'); }
"?"                     { count(); return('?'); }

[ \t\v\n\f]             { count(); }
.                       { /* Add code to complain about unmatched characters */ }

%%

static void comment(void)
{
    char c, prev = 0;
  
    while ((c = input()) != 0)      /* (EOF maps to 0) */
    {
        if (c == '\n')
        {
            ++lineno;
            column = 1;
        }
        else
        {
            if (c == '\t')
            {
                column += 8 - (column % 8);
            }
            else
            {
                column++;
            }
        }
        if (c == '/' && prev == '*')
            return;
        prev = c;
    }

    yyerror("unterminated comment");
}

static void count(void)
{
    int i;

    for (i = 0; yytext[i] != '\0'; i++)
    {
        if (yytext[i] == '\n')
        {
            ++lineno;
            column = 1;
        }
        else if (yytext[i] == '\t')
        {
            column += 8 - (column % 8);
        }
        else
        {
            column++;
        }
    }
}

static int check_type(void)
{
    if (in_typedef && (!in_typedef_paren || (in_func_typedef && !in_func_typedef_body)))
    {
        if (is_typedefed(yytext))
        {
            if (!in_func_typedef && !s_typedef_typename)
            {
                return TYPE_NAME;
            }
        }
        else
        {
            if (s_typedef_typename)
            {
                yyerror("multiple types in one declaration");
            }
            else
            {
                s_typedef_typename = strdup(yytext);
                add_typedef(yytext);
            }
        }
    }
    return IDENTIFIER;
}

static void enter_paren(void)
{
    const char *pch;

    if (in_typedef)
    {
        in_typedef_paren++;
        assert(in_typedef_paren > 0);
    }
}

static void leave_paren(void)
{
    if (in_typedef)
    {
        assert(in_typedef_paren > 0);
        in_typedef_paren--;
    }

    if (in_func_typedef)
    {
        in_typedef = 0;
        in_typedef_paren = 0;
        in_func_typedef_body = 1;
    }
}

static void do_semicolon(void)
{
    if (s_typedef_typename)
    {
        free(s_typedef_typename);
        s_typedef_typename = NULL;
    }

    in_typedef = 0;
    in_func_typedef_body = 0;
}

static void do_typedef(void)
{
    in_typedef = 1; 
    in_func_typedef_body = 0;

    if (s_typedef_typename)
    {
        free(s_typedef_typename);
        s_typedef_typename = NULL;
    }
}

static void do_asterisk(void)
{
    if (in_typedef && in_typedef_paren)
        in_func_typedef = 1; 
}
