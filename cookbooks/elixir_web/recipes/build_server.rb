# coding: utf-8
#
# Cookbook:: elixir_web
# Recipe:: build_server // e-deliver/distillery build server recipe to use in an elixir build rig - installs Node and Yarn (for assets), erlang, elixir and git
#
# Copyright:: 2018, @Micael Nussbaumer, licensed under WTFPL (Do What the Fuck You Want To Public License)

app_name = ENV['APP_NAME']
port = ENV['PORT']
swapsize = ENV['SWAPSIZE'] || 1024

deploy_user = ENV['DEPLOYMENT_USER']

ssh_key_path = ENV['SSH_KEY_PATH']

additional_env = {}

File.open("#{ENV['ROOT_PATH']}/chef/environment", "r").each_line do |line|
  next if line !~ /[^[:space:]]/
  split_line = line.split("=")
  additional_env[split_line[0].strip.to_sym] = split_line[1].strip.gsub!(/^\"|\"?$/, '')
end

puts additional_env.inspect

raise "\n\n################\napp_name is not set\n################\n" if app_name !~ /[^[:space:]]/
raise "\n\n################\nport for app is not set\n################\n" if port !~ /[^[:space:]]/
raise "\n\n################\nUser for app is not set\n################\n" if deploy_user !~ /[^[:space:]]/

bash 'set locales' do
  code <<-EOH
  cat /etc/default/locale | grep -q LANG=en_US.UTF-8 || update-locale LANG=en_US.UTF-8 && update-locale LC_ALL=en_US.UTF-8 && update-locale LANGUAGE=en_US.UTF-8
  EOH
end

bash 'update packaged references' do
  code <<-EOH
  wget -O - https://deb.nodesource.com/setup_8.x | sudo -E bash -
  wget --quiet -O - https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
  wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && sudo dpkg -i erlang-solutions_1.0_all.deb
  sudo apt-get update
  EOH
end

apt_package 'build-essential'
apt_package 'git-core'
apt_package 'nodejs'
apt_package 'yarn'
apt_package 'esl-erlang' do
  version '1:20.1'
end
apt_package 'elixir'

group deploy_user
user deploy_user do
  system true
  group deploy_user
  manage_home true
  shell '/bin/bash'
end

directory "/home/#{deploy_user}" do
  owner deploy_user
  group deploy_user
end

apt_package 'emacs' do
  options '--no-install-recommends'
end

directory "/home/#{deploy_user}/.emacs.d" do
  owner deploy_user
  group deploy_user
end

directory "/home/#{deploy_user}/.ssh" do
  owner deploy_user
  group deploy_user
  mode  '0700'
end

file "/home/#{deploy_user}/.ssh/authorized_keys" do
  owner deploy_user
  group deploy_user
  mode  '0600'
  content ::File.open(ssh_key_path).read
end

template "/home/#{deploy_user}/.emacs.d/init.el" do
  owner  deploy_user
  group  deploy_user
  source 'init.el.erb'
end

template "/home/#{deploy_user}/.swapon.sh" do
  source 'swapon.sh.erb'
  owner  deploy_user
  group  deploy_user
  mode   '0700'
  variables(swapsize: swapsize)
end

template "/home/#{deploy_user}/.swapoff.sh" do
  source 'swapon.sh'
  owner  deploy_user
  group  deploy_user
  mode   '0700'
  source 'swapoff.sh'
end

template "/home/#{deploy_user}/config_plain" do
  source 'config_plain.erb'
  group deploy_user
  owner deploy_user
  mode  '0700'
  variables(envs: additional_env)
end

template "/home/#{deploy_user}/config" do
  source 'config_plain.erb'
  group deploy_user
  owner deploy_user
  mode  '0700'
  variables(envs: additional_env, export: true)
end

file "/home/#{deploy_user}/.profile" do
  group deploy_user
  owner deploy_user
  mode '0700'
  action :create_if_missing
end

profile_source = ". \"/home/#{deploy_user}/config\""
bash 'source export vars in .profile' do
  user deploy_user
  code <<-EOH
    if ! grep -q "#{profile_source}" /home/#{deploy_user}/.profile; 
    then (tmpfile=`mktemp` && { echo "#{profile_source}" | cat - /home/#{deploy_user}/.profile > $tmpfile && mv $tmpfile /home/#{deploy_user}/.profile; } );
    fi
  EOH
end

template "/home/#{deploy_user}/prod.secret.exs" do
  source 'prod.secret.exs.erb'
  group deploy_user
  owner deploy_user
  mode '0700'
  variables(envs: additional_env)
end
