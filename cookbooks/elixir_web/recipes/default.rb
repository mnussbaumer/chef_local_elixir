# coding: utf-8
#
# Cookbook:: elixir_web
# Recipe:: default // sets up a stack with a user, emacs, a bash script to enable/disabled a swap partition, nginx with basic http interface to connect to an elixir phoenix app, and a systemd service unit for the app.
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

apt_update 'Update the apt cache daily' do
  frequency 86_400
  action :periodic
end

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

apt_package 'ufw'

apt_package 'emacs' do
  options '--no-install-recommends'
end

apt_package 'nginx' do
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

directory "/home/#{deploy_user}/#{app_name}" do
  owner deploy_user
  group deploy_user
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

template '/etc/nginx/sites-available/web_app' do
  source 'web_app.erb'
  variables(app_name: app_name,
            port: port)
  verify 'nginx -t'
end

link '/etc/nginx/sites-enabled/web_app' do
  to '/etc/nginx/sites-available/web_app'
end

file '/etc/nginx/sites-available/default' do
  action :delete
end

link '/etc/nginx/sites-enabled/default' do
  action :delete
  only_if 'test -L /etc/nginx/sites-enabled/default'
end

bash 'set_ufw' do
  code <<-EOH
  ufw enable
  ufw allow OpenSSH
  ufw allow 'Nginx HTTP'
  EOH
end

service 'nginx' do
  supports status: true
  action   [:enable, :start, :reload]
end

template "/home/#{deploy_user}/#{app_name}/config_plain" do
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

systemd_unit "#{app_name}_server.service" do
  content <<-EOF.gsub(/^\s+/, '')
  [Unit]
  Description=#{app_name} Server
  After=network.target

  [Service]
  User=#{deploy_user}
  Group=#{deploy_user}
  Restart=on-failure

  EnvironmentFile=/home/#{deploy_user}/#{app_name}/config_plain

  ExecStart=/home/#{deploy_user}/#{app_name}/bin/#{app_name} foreground
  ExecStop=/home/#{deploy_user}/#{app_name}/bin/#{app_name} stop

  [Install]
  WantedBy=multi-user.target
  EOF
  verify false
  action [:create, :enable, :reload_or_restart]
end
