MonitorOut : Out
{
    *ar { Error("MonitorOut can only be control-rate. Use 'kr' method instead.").throw; }

    *kr { arg channelsArray;
        ^super.kr(\monitor_out_bus.kr, channelsArray);
    }

    name { ^Out.name.asString }
}
