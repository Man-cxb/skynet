#include "lua.h"
#include "lauxlib.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <md5.h>
#include <time.h>
#include <dirent.h>
#include <sys/stat.h>

#define MAXUNICODE  0x10FFFF
#define iscont(p)   ((*(p) & 0xC0) == 0x80)

static const char *
tolstring(lua_State *L, size_t *sz, int index)
{
    const char *ptr;
    if (lua_isuserdata(L, index))
    {
        ptr = (const char*)lua_touserdata(L, index);
        *sz = (size_t)luaL_checkinteger(L, index + 1);
    }
    else
    {
        ptr = luaL_checklstring(L, index, sz);
    }
    return ptr;
}

static int _copy_userdata(lua_State *L){
    size_t size;
    const char *ptr = tolstring(L, &size, 1);
    void *buffer = lua_newuserdata(L, size);
    memcpy(buffer, ptr, size);
    return 1;
}
static int
_md5(lua_State *L)
{
    size_t size;
    const char *ptr = tolstring(L, &size, 1);
    char temp[HASHSIZE];
    md5(ptr, (long)size, temp);

    char md5str[HASHSIZE * 2];
    int i;
    for (i = 0; i < HASHSIZE; i++)
    {
        snprintf(md5str + i + i, 3, "%02x", (unsigned char)temp[i]);
    }
    lua_pushlstring(L, md5str, HASHSIZE * 2);
    return 1;
}

static int _count_utf8(lua_State *L)
{
    lua_Integer code = lua_tointeger(L, 1);
    lua_Integer chinese_n = lua_tointeger(L, 2);
    lua_Integer literal_n = lua_tointeger(L, 3);
    lua_Integer illegal_n = lua_tointeger(L, 4);
    if (code >= 19968 && code <= 40869)
    {
        chinese_n++;
    }
    else if ((code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122))
    {
        literal_n++;
    }
    else
    {
        illegal_n++;
    }
    lua_pushinteger(L, chinese_n);
    lua_pushinteger(L, literal_n);
    lua_pushinteger(L, illegal_n);
    return 3;
}

static int find_sensword(const char *str1, char *str2)
{
    while(strstr(str1, str2) != NULL)
        return 1;
    return 0;
}

static int _is_contain_sensword(lua_State *L)
{
    size_t size;
    const char *ptr = tolstring(L, &size, 1);
    int is_contain = 0;
    
    const char *filePath = "./cfg/wordfilter.txt";
    if (lua_isstring(L, 2))
    {
        filePath = lua_tostring(L, 2);
    }

    FILE *fp;
    char sensword[100];
    size_t len;
    fp = fopen(filePath, "r+");
    if (fp == NULL)
        return luaL_error(L, "_is_contain_sensword : file open error");
    fseek(fp, 0, SEEK_SET);
    while(!feof(fp))
    {
        fgets(sensword, sizeof(sensword), fp);
        len = strlen(sensword);
        while(len > 0 && (sensword[len-1] == '\r' || sensword[len - 1] == '\n' ))
            sensword[--len] = '\0';
        if (len == 0)
            continue;
        is_contain = find_sensword(ptr, sensword);
        if (is_contain == 1)
        {
            break;
        }
    }
    fclose(fp);
    lua_pushboolean(L, is_contain);
    return 1;
}

static int _get_time(lua_State *L)
{
    struct timespec ti;
    clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &ti);
    lua_pushnumber(L, (ti.tv_sec & 0xffff) + ti.tv_nsec / 1000000000.0);
    return 1;
}

static int _get_time_thread(lua_State *L)
{
    struct timespec ti;
    clock_gettime(CLOCK_THREAD_CPUTIME_ID, &ti);
    lua_pushnumber(L, (ti.tv_sec & 0xffff) + ti.tv_nsec / 1000000000.0);
    return 1;
}

static int _list_dir(lua_State *L)
{
    const char * dirname = luaL_checkstring(L, 1);
    DIR* dp = opendir(dirname);
    if (!dp)
        return 0;
    lua_newtable(L);
    struct dirent* dirp;
    while ((dirp = readdir(dp)) != NULL)
    {
        if (!strcmp(".", dirp->d_name) || !strcmp("..", dirp->d_name))
            continue;
        lua_pushinteger(L, dirp->d_type);
        lua_setfield(L, -2, dirp->d_name);
    }
    closedir(dp);
    return 1;
}

static int
_stat_file(lua_State *L)
{
    const char* path = luaL_checkstring(L, 1);
    struct stat st;
    if (stat(path, &st))
        return 0;
    lua_newtable(L);
    lua_pushinteger(L, st.st_mode);
    lua_setfield(L, -2, "mode");
    lua_pushboolean(L, S_ISDIR(st.st_mode));
    lua_setfield(L, -2, "isdir");
    lua_pushboolean(L, S_ISREG(st.st_mode));
    lua_setfield(L, -2, "isreg");
    lua_pushboolean(L, S_ISLNK(st.st_mode));
    lua_setfield(L, -2, "islnk");
    lua_pushinteger(L, st.st_size);
    lua_setfield(L, -2, "size");
    lua_pushinteger(L, st.st_mtime);
    lua_setfield(L, -2, "time");
    return 1;
}

int
luaopen_misc(lua_State *L)
{
    luaL_checkversion(L);
    luaL_Reg l[] = {
        {"copy_userdata", _copy_userdata},
        {"md5", _md5},
        {"count_utf8", _count_utf8},
        {"is_contain_sensword", _is_contain_sensword},
        {"get_time", _get_time},
        {"get_time_thread", _get_time_thread},
        {"list_dir", _list_dir},
        {"stat_file", _stat_file},
        {NULL, NULL},
    };
    luaL_newlib(L, l);
    return 1;
}