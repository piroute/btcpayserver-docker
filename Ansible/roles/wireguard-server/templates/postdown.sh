# Drop all forwards
iptables -P FORWARD DROP

# Remove all NAT rules
iptables -t nat -F
iptables -t nat -X
