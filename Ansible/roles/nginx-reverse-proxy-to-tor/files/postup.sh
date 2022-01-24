iptables -A INPUT -m state --state RELATED,ESTABLISHED -i wg0 -j ACCEPT
iptables -A FORWARD -i wg0 -j DROP
iptables -A INPUT -i wg0 -j DROP
