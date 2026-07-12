#!/bin/sh
set -eu

apk add --no-cache iptables >/dev/null

rule="-A ufw-user-input -p tcp --dport 80 -j ACCEPT"
tuple="### tuple ### allow tcp 80 0.0.0.0/0 any 0.0.0.0/0 in"

if ! iptables -C ufw-user-input -p tcp --dport 80 -j ACCEPT 2>/dev/null; then
  iptables -I ufw-user-input 1 -p tcp --dport 80 -j ACCEPT
fi

if ! grep -Fq -- "$rule" /host-ufw/user.rules; then
  cp /host-ufw/user.rules "/host-ufw/user.rules.bak-safebyte-$(date +%Y%m%d%H%M%S)"
  awk -v rule="$rule" -v tuple="$tuple" '
    BEGIN { added = 0 }
    /^### END RULES ###$/ && added == 0 {
      print ""
      print tuple
      print rule
      added = 1
    }
    { print }
  ' /host-ufw/user.rules > /tmp/user.rules
  cat /tmp/user.rules > /host-ufw/user.rules
fi

echo "--- runtime ufw-user-input ---"
iptables -S ufw-user-input
echo "--- persistent public http rule ---"
grep -F -- "$rule" /host-ufw/user.rules
