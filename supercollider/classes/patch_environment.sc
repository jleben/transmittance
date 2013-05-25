PatchEnvironment : EnvironmentRedirect
{
	put { arg key, value;
		var cur_value;
		cur_value = envir.at(key);

		case
		{ value.class === NodeDef }
		{
			if (cur_value.class === NodeProxy2)
			{
				cur_value.def = value.def;
				^cur_value;
			}{
				value = NodeProxy2 (key, value.def);
				envir.put(key, value);
				^value;
			}
		}

		{ value.class === FuncDef }
		{
			if (cur_value.class === FuncProxy)
			{
				cur_value.def = value.def;
				cur_value.numChannels = value.numChannels;
				^cur_value;
			}{
				value = FuncProxy (value.def, value.numChannels);
				envir.put(key, value);
				^value;
			}
		}

		{ value.class === Buffer and: { cur_value.class === Buffer }}
		{
			cur_value.free;
			^envir.put(key, value);
		}

		// else
		{ ^envir.put(key, value) };
	}
}

NodeDef {
    var <>def;
    *new { arg def; ^super.newCopyArgs(def) }
}

FuncDef {
	var <def, <numChannels;
	*new { arg def, numChannels = (0);
		^super.newCopyArgs(def, numChannels);
	}
}
