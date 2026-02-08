import { Gtk } from "ags/gtk4"
import CpuStat from "./stats/Cpu"
import RamStat from "./stats/Ram"
import BatteryStat from "./stats/Battery"
import VolumeStat from "./stats/Volume"
import Dashboard from "./Dashboard"

function Separator() {
  return <label cssClasses={["stat-separator"]} label="|" />
}

export default function SystemStats() {
  return (
    <menubutton cssClasses={["system-stats"]} halign={Gtk.Align.END}>
      <box>
        <CpuStat />
        <Separator />
        <RamStat />
        <Separator />
        <BatteryStat />
        <Separator />
        <VolumeStat />
      </box>
      <popover>
        <Dashboard />
      </popover>
    </menubutton>
  )
}
