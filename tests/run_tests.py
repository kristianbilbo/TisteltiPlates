#!/usr/bin/env python3
"""Run isolated Lua behavioral fixtures with a local Lua 5.4 shared library."""
import ctypes
import ctypes.util
import os
from pathlib import Path
import sys
os.chdir(Path(__file__).resolve().parent.parent)
library=ctypes.util.find_library('lua5.4') or ctypes.util.find_library('lua-5.4')
if not library:
    raise SystemExit('Lua 5.4 shared library is required; no dependencies are downloaded.')
lua=ctypes.CDLL(library)
lua.luaL_newstate.restype=ctypes.c_void_p
for name,args,result in [('luaL_openlibs',[ctypes.c_void_p],None),('luaL_loadfilex',[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_char_p],ctypes.c_int),('luaL_loadstring',[ctypes.c_void_p,ctypes.c_char_p],ctypes.c_int),('lua_pcallk',[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_ssize_t,ctypes.c_void_p],ctypes.c_int),('lua_tolstring',[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p],ctypes.c_char_p),('lua_close',[ctypes.c_void_p],None)]:
    fn=getattr(lua,name);fn.argtypes=args;fn.restype=result
failed=0
for path in sorted(Path('.').glob('*.lua'))+([Path(p) for p in sys.argv[1:]] if len(sys.argv)>1 else sorted(Path('tests').glob('test_*.lua'))):
    state=lua.luaL_newstate();lua.luaL_openlibs(state)
    lua.luaL_loadstring(state,b'loadstring=load; unpack=table.unpack');lua.lua_pcallk(state,0,0,0,0,None)
    code=lua.luaL_loadfilex(state,str(path).encode(),None)
    if not code and path.parent==Path('tests'):code=lua.lua_pcallk(state,0,0,0,0,None)
    if code:
        failed+=1;print(f'FAIL {path}: {lua.lua_tolstring(state,-1,None).decode()}',flush=True)
    lua.lua_close(state)
print(f'{failed} failures',flush=True)
raise SystemExit(bool(failed))
