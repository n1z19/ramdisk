#!/usr/bin/env bash

set -e

mkdir -p boot/

oscheck=$(uname)

ERR_HANDLER () {
    [ $? -eq 0 ] && exit
    echo "[-] An error occurred"
    rm -rf work
}

trap ERR_HANDLER EXIT

# Check for pyimg4
if ! python3 -c 'import importlib.util; exit(not importlib.util.find_spec("pyimg4"))'; then
    echo '[-] pyimg4 not installed. Press any key to install it, or press ctrl + c to cancel'
    read -n 1 -s
    python3 -m pip install pyimg4
fi

# git submodule update --init --recursive


chmod +x "$oscheck"/*

if [ "$oscheck" = 'Darwin' ]; then
    if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
        echo "[*] Waiting for device in DFU mode"
    fi
    
    while ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); do
        sleep 1
    done
else
    if ! (lsusb 2> /dev/null | grep ' Apple, Inc. Mobile Device (DFU Mode)' >> /dev/null); then
        echo "[*] Waiting for device in DFU mode"
    fi
    
    while ! (lsusb 2> /dev/null | grep ' Apple, Inc. Mobile Device (DFU Mode)' >> /dev/null); do
        sleep 1
    done
fi

check=$("$oscheck"/irecovery -q | grep CPID | sed 's/CPID: //')
replace=$("$oscheck"/irecovery -q | grep MODEL | sed 's/MODEL: //')
deviceid=$("$oscheck"/irecovery -q | grep PRODUCT | sed 's/PRODUCT: //')
ipswurl=$(curl -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$oscheck"/jq '.firmwares | .[] | select(.version=="'$1'")' | "$oscheck"/jq -s '.[0] | .url' --raw-output)

if [ "$ipswurl" = "null" ] || [ -z "$ipswurl" ]; then
    echo "[/] We couldn't get the ipsw curl. we will proceed with -k option with curl"
    ipswurl=$(curl -sL -k "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$oscheck"/jq '.firmwares | .[] | select(.version=="'$1'")' | "$oscheck"/jq -s '.[0] | .url' --raw-output)
fi

if [ -e work ]; then
    rm -rf work
fi


if [ "$1" = 'boot' ]; then
    if [ ! -e boot/${deviceid}/iBSS.img4 ]; then
        echo "[-] Please create an SSH ramdisk first!"
        exit
    fi

    "$oscheck"/gaster pwn
    sleep 1
    "$oscheck"/gaster reset
    sleep 1
    "$oscheck"/irecovery -f boot/${deviceid}/iBSS.img4
    sleep 2
    "$oscheck"/irecovery -f boot/${deviceid}/iBEC.img4
    if [ "$check" = '0x8010' ] || [ "$check" = '0x8015' ] || [ "$check" = '0x8011' ] || [ "$check" = '0x8012' ]; then
        sleep 2
        "$oscheck"/irecovery -c go
    fi
    
    if [ "$cpid" = '0x7000' ] || [ "$cpid" = '0x7001' ]; then
        sleep 10
    else
        sleep 4
    fi
    
    "$oscheck"/irecovery -f boot/${deviceid}/bootlogo.img4
    sleep 1
    "$oscheck"/irecovery -c "setpicture 0x1"
    sleep 1
    "$oscheck"/irecovery -f boot/${deviceid}/ramdisk.img4
    sleep 1
    "$oscheck"/irecovery -c ramdisk
    sleep 1
    "$oscheck"/irecovery -f boot/${deviceid}/devicetree.img4
    sleep 1
    "$oscheck"/irecovery -c devicetree
    sleep 1
    "$oscheck"/irecovery -f boot/${deviceid}/trustcache.img4
    sleep 1
    "$oscheck"/irecovery -c firmware
    sleep 1
    "$oscheck"/irecovery -f boot/${deviceid}/kernelcache.img4
    sleep 1
    "$oscheck"/irecovery -c bootx

    exit
fi

if [ ! -e boot/${deviceid} ]; then
    mkdir boot/${deviceid}
fi

if [ -e boot/${deviceid}/iBSS.img4 ]; then
    echo "[-] Ramdisk is already created so SKIPPING ..."
    exit
fi

if [ -z "$1" ]; then
    printf "1st argument: iOS version for the ramdisk\n"
    exit
fi

if [ ! -e work ]; then
    mkdir work
fi


"$oscheck"/gaster pwn
"$oscheck"/img4tool -e -s shsh/"${check}".shsh -m work/IM4M

cd work
../"$oscheck"/pzb -g BuildManifest.plist "$ipswurl"
../"$oscheck"/pzb -g "$(awk "/""${replace}""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"
../"$oscheck"/pzb -g "$(awk "/""${replace}""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"
../"$oscheck"/pzb -g "$(awk "/""${replace}""/{x=1}x&&/DeviceTree[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"

if [ "$oscheck" = 'Darwin' ]; then
    ../"$oscheck"/pzb -g Firmware/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)".trustcache "$ipswurl"
else
    ../"$oscheck"/pzb -g Firmware/"$(../Linux/PlistBuddy BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')".trustcache "$ipswurl"
fi

../"$oscheck"/pzb -g "$(awk "/""${replace}""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"

if [ "$oscheck" = 'Darwin' ]; then
    ../"$oscheck"/pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" "$ipswurl"
else
    ../"$oscheck"/pzb -g "$(../Linux/PlistBuddy BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')" "$ipswurl"
fi

cd ..
"$oscheck"/gaster decrypt work/"$(awk "/""${replace}""/{x=1}x&&/iBSS[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" work/iBSS.dec
"$oscheck"/gaster decrypt work/"$(awk "/""${replace}""/{x=1}x&&/iBEC[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" work/iBEC.dec
"$oscheck"/iBoot64Patcher work/iBSS.dec work/iBSS.patched
"$oscheck"/img4 -i work/iBSS.patched -o boot/${deviceid}/iBSS.img4 -M work/IM4M -A -T ibss
"$oscheck"/iBoot64Patcher work/iBEC.dec work/iBEC.patched -b "rd=md0 debug=0x2014e -v wdt=-1 `if [ "$check" = '0x8960' ] || [ "$check" = '0x7000' ] || [ "$check" = '0x7001' ]; then echo "nand-enable-reformat=1 -restore"; fi`" -n
"$oscheck"/img4 -i work/iBEC.patched -o boot/${deviceid}/iBEC.img4 -M work/IM4M -A -T ibec

"$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/kernelcache.release/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" -o work/kcache.raw
"$oscheck"/Kernel64Patcher work/kcache.raw work/kcache.patched -a
"$oscheck"/kerneldiff work/kcache.raw work/kcache.patched work/kc.bpatch
"$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/kernelcache.release/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" -o boot/${deviceid}/kernelcache.img4 -M work/IM4M -T rkrn -P work/kc.bpatch `if [ "$oscheck" = 'Linux' ]; then echo "-J"; fi`
"$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/DeviceTree[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]//')" -o boot/${deviceid}/devicetree.img4 -M work/IM4M -T rdtr

if [ "$oscheck" = 'Darwin' ]; then
    "$oscheck"/img4 -i work/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)".trustcache -o boot/${deviceid}/trustcache.img4 -M work/IM4M -T rtsc
    "$oscheck"/img4 -i work/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" -o work/ramdisk.dmg
else
    "$oscheck"/img4 -i work/"$(Linux/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')".trustcache -o boot/${deviceid}/trustcache.img4 -M work/IM4M -T rtsc
    "$oscheck"/img4 -i work/"$(Linux/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')" -o work/ramdisk.dmg
fi

chmod +x other/trollstore/usr/bin/*
if [ "$oscheck" = 'Darwin' ]; then
    hdiutil resize -size 258MB work/ramdisk.dmg
    hdiutil attach -mountpoint /tmp/SSHRD work/ramdisk.dmg

    cp -rv other/trollstore/ /tmp/SSHRD/
    "$oscheck"/gtar -x --no-overwrite-dir -f other/ramdisk.tar.gz -C /tmp/SSHRD/

    #if [ ! "$2" = 'rootless' ]; then
    #    curl -LO https://nightly.link/elihwyma/Pogo/workflows/build/root/Pogo.zip
    #    mv Pogo.zip work/Pogo.zip
    #    unzip work/Pogo.zip -d work/Pogo
    #    unzip work/Pogo/Pogo.ipa -d work/Pogo/Pogo
    #    rm -rf /tmp/SSHRD/usr/local/bin/loader.app/*
    #    cp -R work/Pogo/Pogo/Payload/Pogo.app/* /tmp/SSHRD/usr/local/bin/loader.app
    #    mv /tmp/SSHRD/usr/local/bin/loader.app/Pogo /tmp/SSHRD/usr/local/bin/loader.app/Tips
    #fi

    hdiutil detach -force /tmp/SSHRD
    hdiutil resize -sectors min work/ramdisk.dmg
else
    if [ -f other/ramdisk.tar.gz ]; then
        gzip -f -k -d other/ramdisk.tar.gz
    fi

    "$oscheck"/hfsplus work/ramdisk.dmg grow 300000000 > /dev/null
    "$oscheck"/hfsplus work/ramdisk.dmg untar other/ramdisk.tar > /dev/null
    "$oscheck"/hfsplus work/ramdisk.dmg addall other/trollstore > /dev/null

    #if [ ! "$2" = 'rootless' ]; then
    #    curl -LO https://nightly.link/elihwyma/Pogo/workflows/build/root/Pogo.zip
    #    mv Pogo.zip work/Pogo.zip
    #    unzip work/Pogo.zip -d work/Pogo
    #    unzip work/Pogo/Pogo.ipa -d work/Pogo/Pogo
    #    mkdir -p work/Pogo/uwu/usr/local/bin/loader.app
    #    cp -R work/Pogo/Pogo/Payload/Pogo.app/* work/Pogo/uwu/usr/local/bin/loader.app

    #    "$oscheck"/hfsplus work/ramdisk.dmg rmall usr/local/bin/loader.app > /dev/null
    #    "$oscheck"/hfsplus work/ramdisk.dmg addall work/Pogo/uwu > /dev/null
    #    "$oscheck"/hfsplus work/ramdisk.dmg mv /usr/local/bin/loader.app/Pogo /usr/local/bin/loader.app/Tips > /dev/null
    #fi
fi
python3 -m pyimg4 im4p create -i work/ramdisk.dmg -o work/ramdisk.im4p -f rdsk
python3 -m pyimg4 img4 create -p work/ramdisk.im4p -m work/IM4M -o boot/${deviceid}/ramdisk.img4
"$oscheck"/img4 -i other/bootlogo.im4p -o boot/${deviceid}/bootlogo.img4 -M work/IM4M -A -T rlgo

rm -rf work