WAN=ens5
LAN=wg0

# ACCPET forwards from WAN to 9735
iptables -A FORWARD -i $WAN -p tcp --dport 9735 -j ACCEPT
# ACCPET forwards going back and forth
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

# Add NAT rules
iptables -t nat -A PREROUTING -p tcp -i $WAN --dport 9735 -j DNAT --to-destination 10.200.200.2:9735
iptables -t nat -A POSTROUTING -o $WAN -j MASQUERADE
iptables -t nat -A POSTROUTING -o $LAN -j MASQUERADE
