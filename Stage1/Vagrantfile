Vagrant.configure(2) do |config|
  config.vm.box = "anthshor/OracleLinux66"
  config.vm.hostname = "logitech.sprite.zero"
  #to cache yum
  config.vm.synced_folder "yum/", "/var/cache/yum", create: true
  if RUBY_PLATFORM == "universal.x86_64-darwin12.5.0"
    config.vm.synced_folder "/Users/anthonyshorter/Dropbox/Hashicorp/Vagrant/software", "/u01/software", create: true
  else
    config.vm.synced_folder "/Users/anthonysh.DATACOM/Dropbox/Hashicorp/Vagrant/software", "/u01/software", create: true
  end
  config.vm.network "private_network", ip: "192.168.33.11" 
  config.vm.provider :virtualbox do |vb|
    # Need to add the controller to the base box
    unless File.exists?('asmdisk1.vdi')
      vb.customize ['createhd', '--filename', 'asmdisk1', '--size', '5128']
    end  
    vb.customize ['modifyvm', :id, '--memory', '4096']
    vb.customize ['storageattach', :id, '--storagectl', 'SATA', '--port', '0', '--device', '0', '--type', 'hdd', '--medium', 'asmdisk1.vdi']
  end
  config.vm.provision "shell",  path: "provision.sh"
end
