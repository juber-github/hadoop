#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright cloudAge 2015

# Function to discover basic OS details.
discover_os () {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu
    OS=`lsb_release -is`
    # 7.2.1511, 14.04
    OSVER=`lsb_release -rs`
    # 7, 14
    OSREL=`echo $OSVER | awk -F. '{print $1}'`
    # trusty, wheezy, Final
    OSNAME=`lsb_release -cs`
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        OS=CentOS
      else
        OS=RedHatEnterpriseServer
      fi
      OSVER=`rpm -qf /etc/redhat-release --qf="%{VERSION}.%{RELEASE}\n"`
      OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n" | awk -F. '{print $1}'`
    fi
  fi
}

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Ubuntu ]; then
#if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Debian -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Disabling iptables..."
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  if [ $OSREL == 6 ]; then
    service iptables stop
    chkconfig iptables off
#    service ip6tables stop
#    chkconfig ip6tables off
  else
    service firewalld stop
    chkconfig firewalld off
    service iptables stop
    chkconfig iptables off
#    service ip6tables stop
#    chkconfig ip6tables off
  fi
elif [ "$OS" == Ubuntu ]; then
  service ufw stop
  ufw disable
elif [ "$OS" == Debian ]; then
  # https://www.cyberciti.biz/faq/debian-iptables-stop/
  iptables -F
  iptables -X
  iptables -t nat -F
  iptables -t nat -X
  iptables -t mangle -F
  iptables -t mangle -X
  iptables -P INPUT ACCEPT
  iptables -P OUTPUT ACCEPT
  iptables -P FORWARD ACCEPT
fi

#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright CloudAge 2016

DATE=$(date +'%Y%m%d%H%M%S')

# Function to discover basic OS details.
discover_os () {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu
    OS=$(lsb_release -is)
    # 7.2.1511, 14.04
    OSVER=$(lsb_release -rs)
    # 7, 14
    OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
    # trusty, wheezy, Final
    OSNAME=$(lsb_release -cs)
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        OS=CentOS
      else
        OS=RedHatEnterpriseServer
      fi
      OSVER=$(rpm -qf /etc/redhat-release --qf="%{VERSION}.%{RELEASE}\n")
      OSREL=$(rpm -qf /etc/redhat-release --qf="%{VERSION}\n" | awk -F. '{print $1}')
    fi
  fi
}

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "** Before disabling IPv6:"
ip -6 address

if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  echo "** sysctl method"
  echo "** Disabling IPv6 kernel configuration..."
  # https://access.redhat.com/solutions/8709
  # https://wiki.centos.org/FAQ/CentOS7#head-8984faf811faccca74c7bcdd74de7467f2fcd8ee
  # https://wiki.centos.org/FAQ/CentOS6#head-d47139912868bcb9d754441ecb6a8a10d41781df
  if [ -d /etc/sysctl.d ]; then
    if grep -q net.ipv6.conf.all.disable_ipv6 /etc/sysctl.conf; then
      sed -i -e '/^net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
    fi
    if grep -q net.ipv6.conf.default.disable_ipv6 /etc/sysctl.conf; then
      sed -i -e '/^net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
    fi
    echo "# Tuning for Hadoop installation." >/etc/sysctl.d/cloudera-ipv6.conf
    echo "# CloudAge" >>/etc/sysctl.d/cloudera-ipv6.conf
    echo "net.ipv6.conf.all.disable_ipv6 = 1" >>/etc/sysctl.d/cloudera-ipv6.conf
    echo "net.ipv6.conf.default.disable_ipv6 = 1" >>/etc/sysctl.d/cloudera-ipv6.conf
    chown root:root /etc/sysctl.d/cloudera-ipv6.conf
    chmod 0644 /etc/sysctl.d/cloudera-ipv6.conf
    sysctl -p /etc/sysctl.d/cloudera-ipv6.conf
    if [ "$OSREL" == 7 ]; then
      dracut -f
    elif [ "$OSREL" == 6 ]; then
      cp -p /etc/hosts /etc/hosts.${DATE}
      sed -i -e 's/^[[:space:]]*::/#::/' /etc/hosts
    fi
  else
    if grep -q net.ipv6.conf.all.disable_ipv6 /etc/sysctl.conf; then
      sed -i -e "/^net.ipv6.conf.all.disable_ipv6/s|=.*|= 1|" /etc/sysctl.conf
    else
      echo "net.ipv6.conf.all.disable_ipv6 = 1" >>/etc/sysctl.conf
    fi
    if grep -q net.ipv6.conf.default.disable_ipv6 /etc/sysctl.conf; then
      sed -i -e "/^net.ipv6.conf.default.disable_ipv6/s|=.*|= 1|" /etc/sysctl.conf
    else
      echo "net.ipv6.conf.default.disable_ipv6 = 1" >>/etc/sysctl.conf
    fi
    sysctl -p /etc/sysctl.conf
  fi

#  if [ "$OSREL" == 7 ]; then
#    echo "** kernel module method"
#    echo "** Disabling IPv6 kernel module..."
#    cp -p /etc/default/grub /etc/default/grub.${DATE}
#    # Alternatively use "ipv6.disable_ipv6=1".
#    if grep -q ipv6.disable /etc/default/grub; then
#      sed -i -e '/^GRUB_CMDLINE_LINUX=/s|ipv6.disable=.|ipv6.disable=1|' /etc/default/grub
#    else
#      sed -i -e '/^GRUB_CMDLINE_LINUX=/s|"$| ipv6.disable=1"|' /etc/default/grub
#    fi
#    if [ -f /boot/efi/EFI/redhat/grub.cfg ]; then
#      grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg
#    else
#      grub2-mkconfig -o /boot/grub2/grub.cfg
#    fi
#  elif [ "$OSREL" == 6 ]; then
#    echo "** kernel module method"
#    echo "** Disabling IPv6 kernel module..."
#    cat <<EOF >/etc/modprobe.d/cloudera-ipv6.conf
## CloudAge
## Tuning for Hadoop installation.
#options ipv6 disable=1
#EOF
#    chown root:root /etc/modprobe.d/cloudera-ipv6.conf
#    chmod 0644 /etc/modprobe.d/cloudera-ipv6.conf
#    echo "** Unloading IPv6 kernel module..."
#    rmmod ipv6 &>/dev/null
#  fi

  echo "** Stopping IPv6 firewall..."
  service ip6tables stop
  chkconfig ip6tables off

elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  echo "** sysctl method"
  echo "** Disabling IPv6 kernel configuration..."
  # https://wiki.debian.org/DebianIPv6#How_to_turn_off_IPv6
  # https://wiki.ubuntu.com/IPv6#Disabling_IPv6
  # https://askubuntu.com/questions/440649/how-to-disable-ipv6-in-ubuntu-14-04
  if grep -q net.ipv6.conf.all.disable_ipv6 /etc/sysctl.conf; then
    sed -i -e '/^net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
  fi
  if grep -q net.ipv6.conf.default.disable_ipv6 /etc/sysctl.conf; then
    sed -i -e '/^net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
  fi
  #if grep -q net.ipv6.conf.lo.disable_ipv6 /etc/sysctl.conf; then
  #  sed -i -e '/^net.ipv6.conf.lo.disable_ipv6/d' /etc/sysctl.conf
  #fi
  echo "# Tuning for Hadoop installation." >/etc/sysctl.d/cloudera-ipv6.conf
  echo "# CloudAge" >>/etc/sysctl.d/cloudera-ipv6.conf
  echo "net.ipv6.conf.all.disable_ipv6 = 1" >>/etc/sysctl.d/cloudera-ipv6.conf
  echo "net.ipv6.conf.default.disable_ipv6 = 1" >>/etc/sysctl.d/cloudera-ipv6.conf
  #echo "net.ipv6.conf.lo.disable_ipv6 = 1" >>/etc/sysctl.d/cloudera-ipv6.conf
  chown root:root /etc/sysctl.d/cloudera-ipv6.conf
  chmod 0644 /etc/sysctl.d/cloudera-ipv6.conf
  service procps restart
fi
# https://www.suse.com/support/kb/doc.php?id=7015035
# https://www.suse.com/support/kb/doc/?id=7012111

echo "** After disabling IPv6:"
ip -6 address

# Fix any breakage in other applications.
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  if rpm -q postfix >/dev/null; then
    echo "** Disabling IPv6 in Postfix..."
    cp -p /etc/postfix/main.cf /etc/postfix/main.cf.${DATE}
#mja needs work : assumes 127.0.0.1
    postconf inet_interfaces
    postconf -e inet_interfaces=127.0.0.1
    service postfix condrestart
  fi
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  :
fi

echo "** Disabling IPv6 in /etc/ssh/sshd_config..."
cp -p /etc/ssh/sshd_config /etc/ssh/sshd_config.${DATE}
sed -e '/# CloudAge$/d' \
    -e '/^AddressFamily /d' \
    -e '/^ListenAddress /d' \
    -i /etc/ssh/sshd_config
#mja needs work : assumes 0.0.0.0
cat <<EOF >>/etc/ssh/sshd_config
# Hadoop: Disable IPv6 support # CloudAge
AddressFamily inet             # CloudAge
ListenAddress 0.0.0.0          # CloudAge
# Hadoop: Disable IPv6 support # CloudAge
EOF
service ssh restart

if [ -f /etc/netconfig ]; then
  echo "** Disabling IPv6 in netconfig..."
  cp -p /etc/netconfig /etc/netconfig.${DATE}
  sed -e '/inet6/d' -i /etc/netconfig
fi

#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright CloudAge 2015

# Function to discover basic OS details.
discover_os () {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu
    OS=`lsb_release -is`
    # 7.2.1511, 14.04
    OSVER=`lsb_release -rs`
    # 7, 14
    OSREL=`echo $OSVER | awk -F. '{print $1}'`
    # trusty, wheezy, Final
    OSNAME=`lsb_release -cs`
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        OS=CentOS
      else
        OS=RedHatEnterpriseServer
      fi
      OSVER=`rpm -qf /etc/redhat-release --qf="%{VERSION}.%{RELEASE}\n"`
      OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n" | awk -F. '{print $1}'`
    fi
  fi
}

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Disabling SElinux..."
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  setenforce 0
  sed -i -e '/^SELINUX=/s|=.*|=disabled|' /etc/selinux/config
fi

#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright CloudAge 2015

# Function to discover basic OS details.
discover_os () {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu
    OS=`lsb_release -is`
    # 7.2.1511, 14.04
    OSVER=`lsb_release -rs`
    # 7, 14
    OSREL=`echo $OSVER | awk -F. '{print $1}'`
    # trusty, wheezy, Final
    OSNAME=`lsb_release -cs`
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        OS=CentOS
      else
        OS=RedHatEnterpriseServer
      fi
      OSVER=`rpm -qf /etc/redhat-release --qf="%{VERSION}.%{RELEASE}\n"`
      OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n" | awk -F. '{print $1}'`
    fi
  fi
}

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Debian -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Disabling Transparent Huge Pages..."
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  if [ $OSREL == 6 ]; then
    echo never >/sys/kernel/mm/transparent_hugepage/defrag
    echo never >/sys/kernel/mm/transparent_hugepage/enabled
    sed -i '/transparent_hugepage/d' /etc/rc.d/rc.local
    echo 'echo never >/sys/kernel/mm/transparent_hugepage/defrag' >>/etc/rc.d/rc.local
    echo 'echo never >/sys/kernel/mm/transparent_hugepage/enabled' >>/etc/rc.d/rc.local
  else
    # http://www.certdepot.net/rhel7-rc-local-service/
    sed -i '/transparent_hugepage/d' /etc/rc.d/rc.local
    echo 'echo never >/sys/kernel/mm/transparent_hugepage/defrag' >>/etc/rc.d/rc.local
    echo 'echo never >/sys/kernel/mm/transparent_hugepage/enabled' >>/etc/rc.d/rc.local
    chmod +x /etc/rc.d/rc.local
    systemctl start rc-local
  fi
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  echo never >/sys/kernel/mm/transparent_hugepage/defrag
  echo never >/sys/kernel/mm/transparent_hugepage/enabled
  sed -e '/transparent_hugepage/d' \
      -e '/^exit 0/i \
echo never >/sys/kernel/mm/transparent_hugepage/defrag\
echo never >/sys/kernel/mm/transparent_hugepage/enabled' \
      -i /etc/rc.local
fi

#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright CloudAge 2017

# Function to discover basic OS details.
discover_os () {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu
    OS=$(lsb_release -is)
    # 7.2.1511, 14.04
    OSVER=$(lsb_release -rs)
    # 7, 14
    OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
    # trusty, wheezy, Final
    OSNAME=$(lsb_release -cs)
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        OS=CentOS
      else
        OS=RedHatEnterpriseServer
      fi
      OSVER=$(rpm -qf /etc/redhat-release --qf="%{VERSION}.%{RELEASE}\n")
      OSREL=$(rpm -qf /etc/redhat-release --qf="%{VERSION}\n" | awk -F. '{print $1}')
    fi
  fi
}

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Installing LZO libraries..."
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  yum -y -e1 -d1 install lzo
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get -y -q install liblzo2-2
fi

#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright CloudAge 2016

# Function to discover basic OS details.
discover_os () {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu
    OS=`lsb_release -is`
    # 7.2.1511, 14.04
    OSVER=`lsb_release -rs`
    # 7, 14
    OSREL=`echo $OSVER | awk -F. '{print $1}'`
    # trusty, wheezy, Final
    OSNAME=`lsb_release -cs`
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        OS=CentOS
      else
        OS=RedHatEnterpriseServer
      fi
      OSVER=`rpm -qf /etc/redhat-release --qf="%{VERSION}.%{RELEASE}\n"`
      OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n" | awk -F. '{print $1}'`
    fi
  fi
}

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Debian -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Installing Name Service Caching Daemon..."
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  yum -y -e1 -d1 install nscd
  service nscd start
  chkconfig nscd on
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get -y -q install nscd
  service nscd start
  update-rc.d nscd defaults
fi

#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright CloudAge 2015

# Function to discover basic OS details.
discover_os () {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu
    OS=`lsb_release -is`
    # 7.2.1511, 14.04
    OSVER=`lsb_release -rs`
    # 7, 14
    OSREL=`echo $OSVER | awk -F. '{print $1}'`
    # trusty, wheezy, Final
    OSNAME=`lsb_release -cs`
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        OS=CentOS
      else
        OS=RedHatEnterpriseServer
      fi
      OSVER=`rpm -qf /etc/redhat-release --qf="%{VERSION}.%{RELEASE}\n"`
      OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n" | awk -F. '{print $1}'`
    fi
  fi
}

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Debian -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Installing tools..."
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  yum -y -e1 -d1 install epel-release
  if ! rpm -q epel-release; then
    rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSREL}.noarch.rpm
  fi
  if [ "$OS" == RedHatEnterpriseServer ]; then
    subscription-manager repos --enable=rhel-${OSREL}-server-optional-rpms
  fi
  yum -y -e1 -d1 install wget unzip deltarpm
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get -y -q install wget curl unzip
fi

#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright CloudAge 2016

# Function to discover basic OS details.
discover_os () {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu
    OS=`lsb_release -is`
    # 7.2.1511, 14.04
    OSVER=`lsb_release -rs`
    # 7, 14
    OSREL=`echo $OSVER | awk -F. '{print $1}'`
    # trusty, wheezy, Final
    OSNAME=`lsb_release -cs`
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        OS=CentOS
      else
        OS=RedHatEnterpriseServer
      fi
      OSVER=`rpm -qf /etc/redhat-release --qf="%{VERSION}.%{RELEASE}\n"`
      OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n" | awk -F. '{print $1}'`
    fi
  fi
}

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
# Only available on EL.
discover_os
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Removing tuned..."
rpm -e tuned

#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright CloudAge 2017

# https://access.redhat.com/sites/default/files/attachments/20150325_network_performance_tuning.pdf
# https://docs.aws.amazon.com/AmazonS3/latest/dev/TCPWindowScaling.html
# https://docs.aws.amazon.com/AmazonS3/latest/dev/TCPSelectiveAcknowledgement.html
# http://www.cloudera.com/documentation/other/reference-architecture/PDF/cloudera_ref_arch_metal.pdf

# Cloudera Professional Services recommendations:
DATA="net.core.netdev_max_backlog = 250000
net.core.optmem_max = 4194304
net.core.rmem_default = 4194304
net.core.rmem_max = 4194304
net.core.wmem_default = 4194304
net.core.wmem_max = 4194304
net.ipv4.tcp_adv_win_scale = 1
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_rmem = 4096 87380 4194304
net.ipv4.tcp_wmem = 4096 65536 4194304"

# Page allocation errors are likely happening due to higher network load where
# kernel cannot allocate a contiguous chunk of memory for a network interrupt.
# This happens on 10GbE interfaces of various manufacturers.
#vm.min_free_kbytes = 1048576

# Function to discover basic OS details.
discover_os () {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu
    OS=$(lsb_release -is)
    # 7.2.1511, 14.04
    OSVER=$(lsb_release -rs)
    # 7, 14
    OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
    # trusty, wheezy, Final
    OSNAME=$(lsb_release -cs)
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        OS=CentOS
      else
        OS=RedHatEnterpriseServer
      fi
      OSVER=$(rpm -qf /etc/redhat-release --qf="%{VERSION}.%{RELEASE}\n")
      OSREL=$(rpm -qf /etc/redhat-release --qf="%{VERSION}\n" | awk -F. '{print $1}')
    fi
  fi
}

_sysctld () {
  FILE=/etc/sysctl.d/cloudera-network.conf

  install -m 0644 -o root -g root /dev/null "$FILE"
  cat <<EOF >"${FILE}"
# Tuning for Hadoop installation. CloudAge
# Based on Cloudera Professional Services recommendations.
$DATA
EOF
}

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Tuning Kernel parameters..."
FILE=/etc/sysctl.conf

if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  if [ ! -d /etc/sysctl.d ]; then
    for PARAM in $(echo "$DATA" | awk '{print $1}'); do
      VAL=$(echo "$DATA" | awk -F= "/^${PARAM} = /{print \$2}" | sed -e 's|^ ||')
      if grep -q "$PARAM" "$FILE"; then
        sed -i -e "/^${PARAM}/s|=.*|= $VAL|" "$FILE"
      else
        echo "${PARAM} = ${VAL}" >>"${FILE}"
      fi
    done
  else
    for PARAM in $(echo "$DATA" | awk '{print $1}'); do
      if grep -q "$PARAM" "$FILE"; then
        sed -i -e "/^${PARAM}/d" "$FILE"
      fi
    done
    _sysctld
  fi
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  for PARAM in $(echo "$DATA" | awk '{print $1}'); do
    if grep -q "$PARAM" "$FILE"; then
      sed -i -e "/^${PARAM}/d" "$FILE"
    fi
  done
  _sysctld
fi

echo "** Applying Kernel parameters."
sysctl -p "$FILE"

#install ntp server
timedatectl status
sudo timedatectl set-timezone Asia/Kolkata
sudo yum install ntp 
timedatectl status

#swappiness
sudo su
echo 1 > /proc/sys/vm/swappiness
exit

sudo shutdown -r now

