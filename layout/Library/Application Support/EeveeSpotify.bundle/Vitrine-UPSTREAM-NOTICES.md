# Third-party code of the audio effects

Built by `Makefile` into `build/<platform>/libsgaudio.a`, which `tweak/Makefile` links. Only the files the
effects compile are here, each unchanged, with its project's license beside it.

| Directory | What for | Upstream | Commit | License |
|---|---|---|---|---|
| `libbs2b/` | Crossfeed | github.com/alexmarsev/libbs2b: `src/bs2b.c`, `bs2b.h`, `bs2btypes.h`, `bs2bversion.h` | `5ca2d59888df047f1e4b028e3a2fd5be8b5a7277` | MIT (`COPYING`) |
| `wdl/` | Liveprog (EEL2, portable bytecode, no JIT) | github.com/justinfrankel/WDL: `WDL/eel2/nseel-compiler.c`, `nseel-eval.c`, `nseel-ram.c`, `ns-eel.h`, `ns-eel-int.h`, `ns-eel-addfuncs.h`, `glue_port.h`; `WDL/wdltypes.h`, `wdlcstring.h`, `utf8_extended.h`, `denormal.h` | `8f4d783de745126ac8c201455dc30818c8613324` | zlib (`LICENSE`) |

`eel2-parser/` is spoti.pw's own code, not third party: EEL2's parser written by hand from `eel2.y`'s grammar,
and `rand()`. Upstream's `y.tab.c`/`y.tab.h` are Bison output (GPL with Bison's exception) and its
`nseel-cfunc.c` carries a Mersenne Twister, so neither is here.


## libbs2b licence

Copyright (c) 2005 Boris Mikhaylov

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


## WDL / EEL2 licence

WDL (github.com/justinfrankel/WDL) is under the zlib license, as its source files state. The EEL2 files here
carry it in their headers:

  Expression Evaluator Library (NS-EEL) v2
  Copyright (C) 2004-2013 Cockos Incorporated
  Copyright (C) 1999-2003 Nullsoft, Inc.

and wdlcstring.h:

  WDL - wdlcstring.h
  Copyright (C) 2005 and later, Cockos Incorporated

The license:

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
