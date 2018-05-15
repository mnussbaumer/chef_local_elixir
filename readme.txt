
Create Amazon EC2 Ubuntu 16.04 image

Ports: SSH 22 (own ip) | http 80 | https 443

Then connect to the instance

ssh ubuntu@ip.addr.of.instance

############# Run on the Instance Shell

sudo apt-get update
sudo apt-get -y install curl

############# If running Chef SK locally

curl https://omnitruck.chef.io/install.sh | sudo bash -s -- -P chefdk -c stable -v 2.5.3


### create cookbook
chef generate cookbook cookbooks/elixir_web



sudo apt-get install emacs --yes

mkdir ~/chef-repo

cd ~/chef-repo

#### hello.rb
#### -> file '/describes/location/of/file' 
#### -> content 'defines content to place inside file'
emacs hello.rb

file '/tmp/motd' do
  content 'hello world'
end

#### apply local changes with chef-client
chef-client --local-mode hello.rb


