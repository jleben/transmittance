PatchEnvironment : EnvironmentRedirect
{
	put { arg key, value;
		var cur_value;
		case
		{ value.class === NodeDef }
		{
			cur_value = envir.at(key);
			if (cur_value.class === NodeProxy2)
			{
				cur_value.def = value.def;
				^cur_value;
			}{
				value = NodeProxy2 (value.def);
				envir.put(key, value);
				^value;
			}
		}
		// else
		{ ^envir.put(key, value) };
	}
}

NodeDef {
    var <>def;
    *new { arg def; ^super.newCopyArgs(def) }
}
