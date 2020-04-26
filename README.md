Disguising "NAT Type" on Nintendo Switch to demonstrate the detection process.
This script acts as an UDP proxy server and imitates the behavior of the gateway for each NAT type.

This is NOT to improve your gaming environment stability, but helpful for understanding the method of UDP hole punching or inspecting the problem.

Nintendo Switch の「接続テスト」に表示される「NATタイプ」の各結果を模倣するスクリプト。
これは技術検証のためのスクリプトであり、インストールしても通信対戦が安定するわけではありません。
日本語での解説記事は https://qiita.com/yokoyama10/items/bccd2434bf9dafa8bb25 を参照。

Setup
=====
1. Check your NAT environment. "Endpoint-Independent Mapping" is required, and "Port Preservation" is preferred.
2. Prepare a Linux machine on the same network subnet as the Nintendo Switch. (using virtual machine is possible)
3. Install `iptables` (You may have to disable `firewalld` or other firewall system) and Ruby.
4. Configure the linux machine as following and start `iptables`.
5. Set the "Gateway" in Nintendo Switch to the linux machine's IP address.

System Configure
----------------
```shell
sysctl -w net.ipv4.conf.all.forwarding=1
sysctl -w net.ipv4.conf.all.send_redirects=0
sysctl -w net.ipv4.conf.ensXXX.send_redirects=0   # 'ensXXX' is name of your network interface
```

/etc/sysconfig/iptables
-----------------------
`192.168.0.177` is your Nintendo Switch's IP addresss.

```
*nat
:PREROUTING ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]

-A PREROUTING  -p udp -s 192.168.0.177 -d 52.199.66.160,13.112.35.82   --dport 10025 -j REDIRECT --to-ports 18825
-A PREROUTING  -p udp -s 192.168.0.177 -d 52.193.120.207,54.64.157.221 --dport 10025 -j REDIRECT --to-ports 19925

COMMIT

*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]

COMMIT
```

Usage
=====
Run `ruby switch_nat.rb [TYPE]`
TYPE can be one of `A`, `B`, `C`, `D` or `F` (lowercase is also allowed).

NAT Type Details
================
Please refer to [RFC4787](https://tools.ietf.org/html/rfc4787) for the terminology definition.

The detection of Nintendo Switch is considered to following behavior:

- Type A: Mapping: "Endpoint-Independent", Filtering: "Endpoint-Independent" or "Address-Dependent Filtering"
- Type B: Mapping: "Endpoint-Independent", Filtering: "Address and Port-Dependent"
- Type C: Mapping: the others, but the source port is predictable.
- Type D: In other cases.
- Type F: Failed to receive UDP packets.

Remarks
=======
Packets are sent back to the Nintendo Switch without spoofing the source address; nevertheless it works currently.
