Server.default.waitForBoot {
	var dir = PathName(thisProcess.nowExecutingPath).pathOnly;
	this.executeFile(dir +/+ "main.scd");
}
