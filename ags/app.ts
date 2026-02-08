import app from "ags/gtk4/app"
import GLib from "gi://GLib"
import Bar from "./widget/Bar"
import { monitorFile } from "ags/file"
import { execAsync } from "ags/process"

const cwd = GLib.get_current_dir()
const cssPath = GLib.build_filenamev([cwd, "style.css"])
const widgetDir = GLib.build_filenamev([cwd, "widget"])

const applyCss = () => {
  app.reset_css()
  app.apply_css(cssPath)
}

const useCss = () => {
  applyCss()
  monitorFile(cssPath, () => {
    applyCss()
  })
}

const useHotReload = () => {
  monitorFile(widgetDir, (file) => {
    if (file.endsWith(".tsx") || file.endsWith(".ts")) {
      console.log(`[Hot Reload] ${file} changed, restarting...`)
      execAsync(["ags", "run", cwd])
      app.quit()
    }
  })
}

app.start({
  main() {
    // app.get_monitors().map(Bar)
    useCss()
    useHotReload()
    Bar(app.get_monitors()[0]) // Testing on second monitor
  },
})
