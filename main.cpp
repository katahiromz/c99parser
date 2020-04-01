extern "C"
{
    #include "c99.tab.h"
}
#include <cstdio>
#include <cstdarg>
#include <set>
#include <string>

std::set<std::string> s_types;
std::string s_file;
int lineno, column;
int error_count;

extern "C"
{
    int yyparse(void);

    void yyerror(const char *format, ...)
    {
        va_list va;
        va_start(va, format);
        printf("%s:%u:%u: error: ", s_file.c_str(), lineno, column);
        vprintf(format, va);
        printf("\n");
        ++error_count;
        va_end(va);
    }

    int is_typedefed(const char *text)
    {
        return s_types.count(text) == 1;
    }

    void add_typedef(const char *text)
    {
        s_types.insert(text);
    }
}

int do_load_file(const char *file)
{
    int ret;
    extern FILE *yyin;

    yyin = fopen(file, "r");
    if (!yyin)
    {
        fprintf(stderr, "Cannot open '%s'\n", file);
        return EXIT_FAILURE;
    }

    lineno = 1;
    column = 1;
    s_file = file;
    error_count = 0;

    ret = yyparse();

    fclose(yyin);

    if (ret || error_count)
    {
        puts("ERROR");
        return 1;
    }

    return ret;
}

int main(int argc, char **argv)
{
    return do_load_file(argv[1]);
}
