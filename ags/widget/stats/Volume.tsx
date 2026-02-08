import { createBinding } from "ags"
import Wp from "gi://AstalWp"

export default function VolumeStat() {
  const wp = Wp.get_default()
  const speaker = wp?.audio?.default_speaker

  if (!speaker) {
    return (
      <box cssClasses={["stat-item", "volume"]}>
        <label cssClasses={["stat-icon"]} label="󰖁" />
        <label cssClasses={["stat-value"]} label="--" />
      </box>
    )
  }

  const icon = createBinding(speaker, "mute").as((muted) => (muted ? "󰖁" : "󰕾"))
  const volume = createBinding(speaker, "volume").as((v) => `${Math.round(v * 100)}%`)

  return (
    <box cssClasses={["stat-item", "volume"]}>
      <label cssClasses={["stat-icon"]} label={icon} />
      <label cssClasses={["stat-value"]} label={volume} />
    </box>
  )
}
