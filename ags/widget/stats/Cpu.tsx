import { createPoll } from "ags/time"

const getCpu = `top -bn1 | grep "Cpu(s)" | awk '{print int($2)}'`

export default function CpuStat() {
  const cpu = createPoll("0", 2000, getCpu)

  return (
    <box cssClasses={["stat-item", "cpu"]}>
      <label cssClasses={["stat-icon"]} label="" />
      <label cssClasses={["stat-value"]} label={cpu.as((v) => `${v}%`)} />
    </box>
  )
}
