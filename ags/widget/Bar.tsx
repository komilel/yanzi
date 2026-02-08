import app from "ags/gtk4/app"
import { Astal, Gdk } from "ags/gtk4"
import Clock from "./Clock"
import SystemStats from "./SystemStats"

export default function Bar(gdkmonitor: Gdk.Monitor) {
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor

  return (
    <window
      visible
      name="bar"
      cssClasses={["Bar"]}
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={TOP | LEFT | RIGHT}
      application={app}
    >
      <centerbox cssName="centerbox">
        <box $type="start" />
        <Clock />
        <SystemStats />
      </centerbox>
    </window>
  )
}
