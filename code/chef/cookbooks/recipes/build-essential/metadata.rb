maintainer        "Opscode, Inc."
maintainer_email  "cookbooks@opscode.com"
license           "Apache 2.0"
description       "Installs C compiler / build tools"
version           "0.7.1"
recipe            "build-essential", "Installs C compiler and build tools on Linux"

%w{ fedora redhat centos ubuntu debian amazon }.each do |os|
  supports os
end
