# Install CoreOS on VMware
## Prerequisites
* DHCP server
* CoreOS cloud-config ISO
```bash
$ ssh-keygen
$ wget https://raw.github.com/coreos/scripts/master/contrib/create-basic-configdrive
$ vi create-basic-configdrive
  - Edit token
$ chmod +x create-basic-configdrive
$ ./create-basic-configdrive -H coreos1 -S ~/.ssh/id_rsa.pub
```

## Steps
* Download latest CoreOS stable OVA from https://stable.release.core-os.net/amd64-usr/current/coreos_production_vmware_ova.ova
* Deploy OVA without power on. You do not have to configure OVA.
* Insert CoreOS cloud-config ISO.
* Power on VM.
* Login CoreOS VM.

```bash
$ ssh -i ~/.ssh/id_rsa.pub core@coreos1
```
