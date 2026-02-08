import { Gtk } from "ags/gtk4"
import { createBinding } from "ags"
import { createPoll } from "ags/time"
import Battery from "gi://AstalBattery"
import Wp from "gi://AstalWp"

const getCpu = `top -bn1 | grep "Cpu(s)" | awk '{print int($2)}'`
const getRam = `free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}'`
const getRamDetailed = `free -h | awk '/Mem:/ {print $3 "/" $2}'`
const getDisk = `df -h / | awk 'NR==2 {print $5}' | tr -d '%'`
const getDiskDetailed = `df -h / | awk 'NR==2 {print $3 "/" $2}'`
const getUptime = `uptime -p | sed 's/up //'`

function ProgressBar({ value, cssClass }: { value: number; cssClass?: string }) {
  return (
    <Gtk.LevelBar
      cssClasses={["progress-bar", cssClass ?? ""]}
      value={Math.min(Math.max(value, 0), 1)}
    />
  )
}

function StatRow({
  label,
  icon,
  value,
  detail,
  cssClass,
}: {
  label: string
  icon: string
  value: number
  detail: string
  cssClass?: string
}) {
  return (
    <box cssClasses={["dashboard-stat", cssClass ?? ""]} orientation={Gtk.Orientation.VERTICAL}>
      <box cssClasses={["stat-header"]}>
        <label cssClasses={["stat-icon"]} label={icon} />
        <label cssClasses={["stat-label"]} label={label} hexpand halign={Gtk.Align.START} />
        <label cssClasses={["stat-detail"]} label={detail} />
      </box>
      <ProgressBar value={value / 100} cssClass={cssClass} />
    </box>
  )
}

export default function Dashboard() {
  const cpu = createPoll("0", 2000, getCpu)
  const ram = createPoll("0", 2000, getRam)
  const ramDetailed = createPoll("...", 2000, getRamDetailed)
  const disk = createPoll("0", 10000, getDisk)
  const diskDetailed = createPoll("...", 10000, getDiskDetailed)
  const uptime = createPoll("...", 60000, getUptime)

  const battery = Battery.get_default()
  const wp = Wp.get_default()
  const speaker = wp?.audio?.default_speaker

  return (
    <box cssClasses={["dashboard"]} orientation={Gtk.Orientation.VERTICAL}>
      <label cssClasses={["dashboard-title"]} label="System Monitor" />

      <box cssClasses={["dashboard-section"]} orientation={Gtk.Orientation.VERTICAL}>
        <StatRow
          label="CPU"
          icon=""
          value={cpu.as((v) => parseInt(v)) as unknown as number}
          detail={cpu.as((v) => `${v}%`) as unknown as string}
          cssClass="cpu"
        />
        <StatRow
          label="RAM"
          icon=""
          value={ram.as((v) => parseInt(v)) as unknown as number}
          detail={ramDetailed as unknown as string}
          cssClass="ram"
        />
        <StatRow
          label="Disk"
          icon="󰋊"
          value={disk.as((v) => parseInt(v)) as unknown as number}
          detail={diskDetailed as unknown as string}
          cssClass="disk"
        />
      </box>

      <box cssClasses={["dashboard-section"]} orientation={Gtk.Orientation.VERTICAL}>
        <box cssClasses={["info-row"]}>
          <label cssClasses={["info-icon"]} label="󰁹" />
          <label cssClasses={["info-label"]} label="Battery" hexpand halign={Gtk.Align.START} />
          <label
            cssClasses={["info-value"]}
            label={createBinding(battery, "percentage").as((p) => `${Math.round(p)}%`)}
          />
        </box>
        {speaker && (
          <box cssClasses={["info-row"]}>
            <label cssClasses={["info-icon"]} label="󰕾" />
            <label cssClasses={["info-label"]} label="Volume" hexpand halign={Gtk.Align.START} />
            <label
              cssClasses={["info-value"]}
              label={createBinding(speaker, "volume").as((v) => `${Math.round(v * 100)}%`)}
            />
          </box>
        )}
        <box cssClasses={["info-row"]}>
          <label cssClasses={["info-icon"]} label="󰅐" />
          <label cssClasses={["info-label"]} label="Uptime" hexpand halign={Gtk.Align.START} />
          <label cssClasses={["info-value"]} label={uptime} />
        </box>
      </box>
    </box>
  )
}
