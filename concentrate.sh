#!/usr/bin/env zsh
# concentrate.sh
# BlueLobster VM manager — interactive event-loop app.
# Shows all VMs with status. Per-VM sub-menu: Connect, Git Sync, Shut Down.
# Connect opens a new terminal window for SSH + Zed, leaving this menu live.
# Requires: jq, BLUE_LOBSTER_API_KEY in environment

BL_API="https://api.bluelobster.ai"

# ── Zed check (one-time on first run) ────────────────────────────────────────
if ! command -v zed &>/dev/null; then
  echo ""
  echo "⚠️  Zed is not installed."
  echo "    Zed is the recommended IDE for Concentrate.ai development."
  echo ""
  read "installzed?  Install Zed now via Homebrew? (y/n): "
  echo ""
  if [[ "$installzed" == "y" ]]; then
    echo "🍺 Installing Zed..."
    brew install --cask zed
    echo ""
    export PATH="$HOME/.local/bin:$PATH"
    if ! command -v zed &>/dev/null; then
      echo "⚠️  Zed installed but CLI not found in PATH yet."
      echo "    Open a new terminal window and run: concentrate"
      exit 0
    else
      echo "✅ Zed installed."
    fi
  else
    echo "   Skipping Zed install. You can install it later with:"
    echo "     brew install --cask zed"
    echo "   The VM manager will work but Connect will not open Zed automatically."
  fi
  echo ""
fi

# ── BL API key check ──────────────────────────────────────────────────────────
if [[ -z "$BLUE_LOBSTER_API_KEY" ]]; then
  echo ""
  echo "❌ BLUE_LOBSTER_API_KEY is not set."
  echo "   Add it to ~/.secrets and run: source ~/.zshrc"
  echo ""
  exit 1
fi

# ── Helper: fetch all instances ───────────────────────────────────────────────
# Populates global arrays: names, ips, pstatuses, usernames, uuids, count
fetch_instances() {
  local raw
  raw=$(curl -sf \
    -H "X-API-Key: $BLUE_LOBSTER_API_KEY" \
    "$BL_API/api/v1/instances") || {
    echo "❌ Could not reach BlueLobster API. Check your key or network."
    return 1
  }
  names=(${(f)"$(echo "$raw" | jq -r '.[].name')"})
  ips=(${(f)"$(echo "$raw" | jq -r '.[].ip_address')"})
  pstatuses=(${(f)"$(echo "$raw" | jq -r '.[].power_status')"})
  usernames=(${(f)"$(echo "$raw" | jq -r '.[].vm_username')"})
  uuids=(${(f)"$(echo "$raw" | jq -r '.[].uuid')"})
  count=${#names[@]}
}

# ── Helper: refresh status for a single VM by index ──────────────────────────
refresh_one() {
  local idx=$1
  local uuid="${uuids[$idx]}"
  local raw
  raw=$(curl -sf \
    -H "X-API-Key: $BLUE_LOBSTER_API_KEY" \
    "$BL_API/api/v1/instances/$uuid") || return 1
  pstatuses[$idx]=$(echo "$raw" | jq -r '.power_status')
  ips[$idx]=$(echo "$raw" | jq -r '.ip_address')
}

# ── Helper: power on a VM and poll until running ──────────────────────────────
power_on() {
  local idx=$1
  local name="${names[$idx]}"
  local uuid="${uuids[$idx]}"

  echo "⚡ Sending power-on request for $name..."
  curl -sf -X POST \
    -H "X-API-Key: $BLUE_LOBSTER_API_KEY" \
    "$BL_API/api/v1/instances/$uuid/power-on" > /dev/null || {
    echo "❌ Power-on request failed."
    return 1
  }

  echo "⏳ Waiting for $name to start..."
  for attempt in {1..24}; do
    sleep 5
    refresh_one $idx
    if [[ "${pstatuses[$idx]}" == "running" ]]; then
      echo "✅ $name is running."
      return 0
    fi
    echo "   still ${pstatuses[$idx]}... ($attempt/24)"
  done
  echo "❌ Timed out. Try again in a moment."
  return 1
}

# ── Helper: git pull + push on VM over SSH (no interactive shell) ─────────────
git_sync_vm() {
  local user=$1
  local ip=$2
  local name=$3
  echo ""
  echo "🔄 Git Sync — $name"
  echo ""
  echo "   Pulling latest from remote..."
  ssh -o ConnectTimeout=10 "$user@$ip" \
    "cd ~/dev_projects && git pull --quiet" 2>&1 | sed 's/^/   /'
  echo ""
  read "dopush?  Push local commits to remote? (y/n): "
  if [[ "$dopush" == "y" ]]; then
    ssh -o ConnectTimeout=10 "$user@$ip" \
      "cd ~/dev_projects && git push" 2>&1 | sed 's/^/   /'
    echo "   ✅ Push complete."
  else
    echo "   Skipped push."
  fi
  echo ""
}

# ── Helper: shut down a VM (with optional git sync first) ─────────────────────
shutdown_vm() {
  local idx=$1
  local name="${names[$idx]}"
  local uuid="${uuids[$idx]}"
  local user="${usernames[$idx]}"
  local ip="${ips[$idx]}"

  echo ""
  if [[ "${pstatuses[$idx]}" != "running" ]]; then
    echo "   $name is already ${pstatuses[$idx]}. Nothing to do."
    echo ""
    return 0
  fi

  read "dosync?  Git Sync before shutting down? (y/n): "
  if [[ "$dosync" == "y" ]]; then
    git_sync_vm "$user" "$ip" "$name"
  fi

  echo "   Sending shutdown request for $name..."
  curl -sf -X POST \
    -H "X-API-Key: $BLUE_LOBSTER_API_KEY" \
    "$BL_API/api/v1/instances/$uuid/shutdown" > /dev/null || {
    echo "❌ Shutdown request failed. Use the BlueLobster dashboard."
    return 1
  }
  pstatuses[$idx]="stopped"
  echo "✅ Shutdown queued. $name will stop shortly."
  echo ""
}

# ── Helper: print the main menu ───────────────────────────────────────────────
print_main_menu() {
  clear
  echo ""
  echo "  🦞 BlueLobster VM Manager"
  echo "  ─────────────────────────────────────────────"
  echo ""
  if [[ $count -eq 0 ]]; then
    echo "  No VMs found on your account."
  else
    for i in {1..$count}; do
      local icon="🔴"
      [[ "${pstatuses[$i]}" == "running" ]] && icon="🟢"
      printf "  %s)  %-22s %s %-10s  %s\n" \
        "$i" "${names[$i]}" "$icon" "${pstatuses[$i]}" "${ips[$i]}"
    done
  fi
  echo ""
  echo "  r)  Refresh"
  echo "  q)  Quit"
  echo ""
}

# ── Helper: print sub-menu for a selected VM ──────────────────────────────────
print_vm_menu() {
  local idx=$1
  local icon="🔴"
  [[ "${pstatuses[$idx]}" == "running" ]] && icon="🟢"

  clear
  echo ""
  echo "  🦞 $icon  ${names[$idx]}  (${pstatuses[$idx]})"
  echo "  ─────────────────────────────────────────────"
  echo ""
  echo "  1)  Connect        (open SSH + Zed in new window)"
  echo "  2)  Git Sync       (pull + push, no SSH change)"
  echo "  3)  Shut Down      (optional git sync, then power off)"
  echo ""
  echo "  b)  Back"
  echo ""
}

# ── Main event loop ───────────────────────────────────────────────────────────
echo ""
echo "   Fetching your BlueLobster VMs..."
fetch_instances || exit 1

while true; do
  print_main_menu
  read "main_choice?  Enter number, r, or q: "
  echo ""

  # Quit
  if [[ "$main_choice" == "q" ]]; then
    local running_names=()
    for i in {1..$count}; do
      [[ "${pstatuses[$i]}" == "running" ]] && running_names+=("${names[$i]}")
    done
    if [[ ${#running_names[@]} -gt 0 ]]; then
      echo "  ⚠️  These VMs are still running:"
      for n in $running_names; do echo "      • $n"; done
      echo ""
      read "force_quit?  Quit anyway without shutting them down? (y/n): "
      echo ""
      [[ "$force_quit" != "y" ]] && continue
    fi
    echo "  👋 Goodbye."
    echo ""
    break
  fi

  # Refresh
  if [[ "$main_choice" == "r" ]]; then
    echo "   Refreshing..."
    fetch_instances || true
    continue
  fi

  # VM selection — validate input
  if ! [[ "$main_choice" =~ ^[0-9]+$ ]] || \
     (( main_choice < 1 || main_choice > count )); then
    echo "  ❌ Invalid choice. Press enter to continue."
    read
    continue
  fi

  sel=$main_choice

  # VM sub-menu loop
  while true; do
    print_vm_menu $sel
    read "vm_choice?  Enter 1, 2, 3, or b: "
    echo ""

    case "$vm_choice" in

      1) # Connect ─────────────────────────────────────────────────────────────
        local name="${names[$sel]}"
        local ip="${ips[$sel]}"
        local user="${usernames[$sel]}"
        local pstatus="${pstatuses[$sel]}"

        if [[ "$pstatus" != "running" ]]; then
          power_on $sel || { read; break; }
          ip="${ips[$sel]}"
        fi

        echo "  🚀 Opening new terminal window for $name..."
        touch /tmp/.concentrate_child
        osascript << APPLESCRIPT
tell application "Terminal"
  do script "\
    echo ''; \
    echo '🔗 Connecting to $name ($user@$ip)...'; \
    echo ''; \
    ssh -o ConnectTimeout=10 $user@$ip 'cd ~/dev_projects && git pull --quiet' 2>/dev/null && echo '   ✅ Git pull complete.'; \
    echo ''; \
    zed 'ssh://$user@$ip/home/$user/dev_projects' 2>/dev/null &; \
    ssh $user@$ip; \
    exit"
  activate
end tell
APPLESCRIPT
        echo "  ✅ Connection window opened."
        echo ""
        refresh_one $sel
        read "?  Press enter to return to menu."
        ;;

      2) # Git Sync ──────────────────────────────────────────────────────────
        if [[ "${pstatuses[$sel]}" != "running" ]]; then
          echo "  ❌ ${names[$sel]} is not running. Start it first with Connect."
          echo ""
          read
        else
          git_sync_vm "${usernames[$sel]}" "${ips[$sel]}" "${names[$sel]}"
          read "?  Press enter to continue."
        fi
        ;;

      3) # Shut Down ────────────────────────────────────────────────────────
        shutdown_vm $sel
        refresh_one $sel 2>/dev/null || pstatuses[$sel]="stopped"
        read "?  Press enter to continue."
        break  # return to main menu after shutdown
        ;;

      b|B)
        break
        ;;

      *)
        echo "  ❌ Invalid choice."
        read
        ;;
    esac
  done

done
