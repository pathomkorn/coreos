# Install CoreOS on VMware

## Pre-Installation
* DHCP server
* Get CoreOS etcd discovery token
```bash
https://discovery.etcd.io/new?size=3
```
* CoreOS cloud-config ISO
```bash
# yum install -y mkisofs
$ ssh-keygen
$ wget https://raw.github.com/coreos/scripts/master/contrib/create-basic-configdrive
$ chmod +x create-basic-configdrive
$ ./create-basic-configdrive -H ${HOSTNAME} -S ~/.ssh/id_rsa.pub -t ${TOKEN}
```

## Installation
* Download latest CoreOS stable OVA.
  * https://stable.release.core-os.net/amd64-usr/current/coreos_production_vmware_ova.ova
* Deploy OVA without power on.
  * Do not configure OVA.
  * OVA configuration done from CoreOS cloud-config ISO.
* Insert CoreOS cloud-config ISO.
* Power on VM.
* Login CoreOS VM.

```bash
$ ssh -i ~/.ssh/id_rsa.pub core@${HOSTNAME}
```

## Post-Installation
* Reconfigure CoreOS
  * Power off.
  * Insert new CoreOS cloud-config ISO.
  * Power on.
