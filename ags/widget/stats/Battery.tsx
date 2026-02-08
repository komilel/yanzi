import { createBinding } from "ags"
import Battery from "gi://AstalBattery"

export default function BatteryStat() {
  const battery = Battery.get_default()

  const icon = createBinding(battery, "percentage").as((p) => {
    if (p >= 90) return "󰁹"
    if (p >= 70) return "󰂁"
    if (p >= 50) return "󰁾"
    if (p >= 30) return "󰁻"
    if (p >= 10) return "󰁺"
    return "󰂃"
  })

  const percentage = createBinding(battery, "percentage").as((p) => `${Math.round(p)}%`)

  return (
    <box cssClasses={["stat-item", "battery"]}>
      <label cssClasses={["stat-icon"]} label={icon} />
      <label cssClasses={["stat-value"]} label={percentage} />
    </box>
  )
}
