/*
  Implementations only suitable for Unix.
  All other platforms need to be rewritten.
*/

#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <error.h>

#include "xmalloc.h"
#include "path.h"

/*----------------------------------------------------------------------------*/
 
char *wiz_path_chop_end(char *path, char **begin){
	int elen, blen;
	char *lsep;
	char *end;
	char *start;
	
	start = path;
	lsep = path - 1;
	while(*path != '\0'){
		if (*path == '/')	
			lsep = path;
		path++;
	}
	elen = strlen(++lsep);
	blen = lsep - start;

	end = xmalloc(elen + 1);
	*begin = xmalloc(blen + 1);

	memcpy(end, lsep, elen);
	end[elen] = '\0';
	memcpy(*begin, start, blen);
	(*begin)[blen] = '\0';
	return end;
}

/*----------------------------------------------------------------------------*/

char *wiz_path_chop_start(char *path, char **end){
	char *start, *result;
	int len;

	start = path;
	while (*start == '/') start++;
	*end = start;
	while (**end != '/' && **end != '\0') (*end)++;

	len = *end - start;
	result = xmalloc(len + 1);
	memcpy(result, start, len);
	result[len] = '\0';
	return result;
}

/*----------------------------------------------------------------------------*/

#define JOIN_ALLOC_SIZE 256

static char *join_one(char *next, char *mem, int memsz, char *cur, va_list args){
	/* next - Next item that needs joining to path.
	 * mem - Beginning of allocated memory.
	 * memsz - Size of allocated memory.
	 * cur - Points to the next available char.
	 * args - Remaining string arguments.
	 */
	char *newmem;
	int newmemsz;
	int nlen;
	int space;

	/* Termination condition */
	if (next == NULL)
	   return mem;
	if (next[0] == '\0')
	   goto next;
	nlen = strlen(next);

	space = (mem + memsz) - cur;
	if (space < nlen + 2){
		/* +2 Enough room for '\0' and '/' chars */
		/* space reused for new allocation size  */
		if (JOIN_ALLOC_SIZE < nlen + 2)
			newmemsz = memsz + nlen + 2 + JOIN_ALLOC_SIZE;
		else
			newmemsz = memsz + JOIN_ALLOC_SIZE;
		
		newmem = xresize(mem, newmemsz);
		mem = newmem;
		memsz = newmemsz;
	}

	if (next[0] == '/'){
		memcpy(mem, next, nlen + 1);
		cur = mem + nlen;
		*cur = '\0';
	} else {
		if (*(cur - 1) != '/') {
		       *(cur++) = '/';
		       *cur = '\0';
		}	       
		memcpy(cur, next, nlen + 1);
		cur += nlen;
	}
next:
	next = va_arg(args, char*); 
	return join_one(next, mem, memsz, cur, args);
}


char *wiz_path_join(const char *fst, ...){
	va_list argp;
	char *mem;
	char *result;
	int memsz;

	memsz = JOIN_ALLOC_SIZE;
	mem = xmalloc(memsz);

	va_start(argp, fst);
	result = join_one(fst, mem, memsz, mem, argp);
	va_end(argp);

	return result;
}
