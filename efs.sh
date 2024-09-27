#!/bin/bash
exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
sudo apt-get update
sudo apt-get install -y nfs-common
sudo mkdir -p /mnt/efs
    
echo "Waiting for EFS to become available..."
while ! sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 10.0.1.163:/ /mnt/efs; do
  sleep 10
  echo "Retrying EFS mount..."
done
echo "10.0.1.163:/ /mnt/efs nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0" | sudo tee -a /etc/fstab
echo "EFS mount completed."