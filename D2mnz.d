module D2mnz;

import core.sys.windows.windows;
import core.sys.windows.dll;

export int foo()
{
	return 42;
}

mixin SimpleDllMain;
