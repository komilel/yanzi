{config, pkgs, ...}: 
let
  Home = "${config.users.users.komi.home}";
  Wallpapers = "${Home}/Wallpapers";
in pkgs.writeShellApplication {
  name = "wallpaper";

  runtimeInputs = with pkgs; [
    swww
    wallust
  ];
  
  text = ''
    # __        __    _ _                                 _     
    # \ \      / /_ _| | |_ __   __ _ _ __   ___ _ __ ___| |__  
    #  \ \ /\ / / _` | | | '_ \ / _` | '_ \ / _ \ '__/ __| '_ \ 
    #   \ V  V / (_| | | | |_) | (_| | |_) |  __/ | _\__ \ | | |
    #    \_/\_/ \__,_|_|_| .__/ \__,_| .__/ \___|_|(_)___/_| |_|
    #                    |_|         |_|                        
    #
    # Wallpaper script for Hyprland with Wallust colors

    # Caching file for current wallpaper
    cache_wallpaper="${Home}/.cache/current_wallpaper"

    # Vars for swww
    transition_type="simple"
    transition_fps=60
    transition_duration=1

    case $1 in
        "select")
            selected=$( find "${Wallpapers}" -maxdepth 1 -type f -exec basename {} \; | shuf | while read -r wall
            do
                echo -en "$wall\x00icon\x1f${Wallpapers}/$wall\n"
            done | rofi -dmenu -i -replace -config ~/.config/rofi/wallpaper.rasi )

            if [ ! "$selected" ]; then
                echo "No wallpaper's selected"
                exit 0
            fi

            # Change color scheme
            wallust run -I background "${Wallpapers}/$selected"

            # Cache wallpaper
            echo "${Wallpapers}/$selected" > "$cache_wallpaper"

            # Change wallpaper with swww
            swww img "${Wallpapers}/$selected" \
                    --transition-type="$transition_type" \
                    --transition-fps=$transition_fps \
                    --transition-duration=$transition_duration

            # Relaunch waybar with new colors
            # killall -SIGUSR2 waybar

            exit 0
        ;;        

        "random")
            # Get random wallpaper from the wallpapers folder
            random_wallpaper=$( find ${Wallpapers} -maxdepth 1 -type f | shuf -n 1 )

            # Random wallpaper change
            wallust run -I background "$random_wallpaper"

            # Cache wallpaper
            echo "$random_wallpaper" > "$cache_wallpaper"

            # Change wallpaper with swww
            swww img "$random_wallpaper" \
                    --transition-type="$transition_type" \
                    --transition-fps=$transition_fps \
                    --transition-duration=$transition_duration

            # Reload waybar with new css
            # killall -SIGUSR2 waybar

            exit 0
        ;;
    esac
  '';
}
