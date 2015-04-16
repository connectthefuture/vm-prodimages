# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.
  config.cache.auto_detect = true
  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "precise64"

  # The url from where the 'config.vm.box' box will be fetched if it
  # doesn't already exist on the user's system.
  config.vm.box_url = "http://files.vagrantup.com/precise64.box"

  # Boot with a GUI so you can see the screen. (Default is headless)
  # config.vm.boot_mode = :gui

  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--memory", "2048"]
  end

  # Assign this VM to a host-only network IP, allowing you to access it
  # via the IP. Host-only networks can talk to the host machine as well as
  # any other machines on the same network, but cannot be accessed (through this
  # network interface) by any external networks.
  # config.vm.network :host-only, "192.168.33.10"

  # Assign this VM to a bridged network, allowing you to connect directly to a
  # network using the host's network device. This makes the VM appear as another
  # physical device on your network.
  # config.vm.network :bridged,  "192.168.2.1"

  # Forward a port from the guest to the host, which allows for outside
  # computers to access the VM, whereas host only networking does not.
  config.vm.network :forwarded_port, guest: 80,   host: 8080
  # config.vm.network :forwarded_port, guest: 22,   host: 2222
  # config.vm.network :forwarded_port, guest: 10000,   host: 10000
  config.vm.network :forwarded_port, guest: 5000, host: 5000
  # config.vm.network :forwarded_port, guest: 8000, host: 8001
  config.vm.network :forwarded_port, guest: 8888, host: 8888
  config.vm.network :forwarded_port, guest: 8082, host: 8082
  config.vm.network :forwarded_port, guest: 8773, host: 8773
  config.vm.network :forwarded_port, guest: 8983, host: 8983
  config.vm.network :forwarded_port, guest: 9000, host: 9000
  config.vm.network :forwarded_port, guest: 3000, host: 3000
  # config.vm.network :forwarded_port, guest: 9999, host: 9999
  config.vm.network :forwarded_port, guest: 27017, host: 27117
  config.vm.network :forwarded_port, guest: 27018, host: 27118
  config.vm.network :forwarded_port, guest: 3301, host: 3301

  # Share an additional folder to the guest VM. The first argument is
  # an identifier, the second is the path on the guest to mount the
  # folder, and the third is the path on the host to the actual folder.
  config.vm.synced_folder "../vdata", "/vagrant_data"
  # config.vm.synced_folder ENV['HOME'], '/mnt'
  # config.vm.synced_folder "../vlinks/MEDIAREPO", "/mnt/MEDIAREPO"


  # Use current users ssh creds ##
  # config.ssh.private_key_path = "~/.ssh/id_rsa"

  # Set host name
  config.vm.hostname = 'prodimages.relic7.org'

  # Enable provisioning with Puppet stand alone.  Puppet manifests
  # are contained in a directory path relative to this Vagrantfile.
  # You will need to create the manifests directory and a manifest in
  # the file site.pp in the manifests_path directory.
  #
  # An example Puppet manifest to provision the message of the day:
  #
  # # group { "puppet":
  # #   ensure => "present",
  # # }
  # #
  # # File { owner => 0, group => 0, mode => 0644 }
  # #
  # # file { '/etc/motd':
  # #   content => "Welcome to your Vagrant-built virtual machine!
  # #               Managed by Puppet.\n"
  # # }
  #
  # config.vm.provision :puppet do |puppet|
  #   puppet.manifests_path = "puppet/manifests"
  #   puppet.manifest_file  = "site.pp"
  # end

  # Copy_my_Cong Vagrant Plugin copies home users dot config files
  # config.vm.provision :copy_my_conf do |copy_conf|
  #  copy_conf.user_home = '/Users/JCut'
  #  copy_conf.git
  #  copy_conf.vim
  #  copy_conf.ssh
  # end

  config.vm.provision :shell do |shell|
  shell.inline = "mkdir -p /etc/puppet/modules;"
                  #puppet module install --force puppetlabs/nodejs;\
                  #puppet module install --force puppetlabs/mongodb;"
  end

  config.vm.provision :puppet do |puppet|
    puppet.manifests_path = "manifests"
    puppet.manifest_file = "site.pp"
    puppet.module_path = "modules"
  end

end
