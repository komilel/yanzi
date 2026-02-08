import { Gtk } from "ags/gtk4"
import { createPoll } from "ags/time"

export default function Clock() {
  const time = createPoll("", 1000, 'date +"%I:%M %p | %a, %b %-d"')

  return (
    <menubutton cssClasses={["clock"]} hexpand halign={Gtk.Align.CENTER}>
      <label label={time} />
      <popover>
        <box cssClasses={["calendar-popup"]}>
          <Gtk.Calendar />
        </box>
      </popover>
    </menubutton>
  )
}
