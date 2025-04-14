# Installation guide for JSON Orin

## Prerequisites:

Install Docker on your target system.
```
sudo apt update; sudo apt install docker.io
```

## Install dreamOS

```
cd installation-scripts\jetson-orin
sed -i -e 's/\r$//' *.sh
chmod +x *.sh
```

Default installation without IVI.  
```
sudo ./dk_install.sh
```

Or install with IVI. It is tested on Raspi5 Raspberry Pi OS and Microsoft Surface ubuntu.  
```
sudo ./dk_install.sh dk_ivi=true
```

## Uninstall dreamOS
```
sudo ./dk_uninstall.sh
```

## Notes:
TBD
