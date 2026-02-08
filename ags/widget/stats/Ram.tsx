import { createPoll } from "ags/time"

const getRam = `free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}'`

export default function RamStat() {
  const ram = createPoll("0", 2000, getRam)

  return (
    <box cssClasses={["stat-item", "ram"]}>
      <label cssClasses={["stat-icon"]} label="" />
      <label cssClasses={["stat-value"]} label={ram.as((v) => `${v}%`)} />
    </box>
  )
}
