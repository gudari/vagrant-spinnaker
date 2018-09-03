# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
    config.vm.box = "bento/ubuntu-16.04"
    config.vm.hostname = "spinnaker.vagrant.local"
    config.vm.network "private_network", ip: "192.168.33.10"
    config.vm.provider "virtualbox" do |vb|
        vb.memory = "4096"
        vb.cpus = 2
        vb.name = "spinnaker.vagrant.local"
    end
    config.vm.synced_folder "/home/" + ENV['USER'] + "/.minikube/", "/minikube"
    config.vm.provision "shell", path: "minio_setup.sh"
    config.vm.provision "shell", path: "setup.sh"
end
