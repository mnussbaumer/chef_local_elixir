app_name = ENV['APP_NAME']
port = ENV['PORT']
domain_main = ENV['DOMAIN_MAIN']
domain_secondary = ENV['DOMAIN_SECONDARY']

raise "\n\n################\napp_name is not set in nginx recipe\n################\n" if app_name !~ /[^[:space:]]/
raise "\n\n################\nport for app is not set in nginx recipe\n################\n" if port !~ /[^[:space:]]/
raise "\n\n################\ndomain_main is not set in nginx recipe\n################\n" if domain_main !~ /[^[:space:]]/
raise "\n\n################\ndomain_secondary for app is not set in nginx recipe\n################\n" if domain_secondary !~ /[^[:space:]]/

template "/etc/nginx/snippets/ssl-#{app_name}.conf" do
  source 'ssl-web_app.conf.erb'
  variables(domain_main: domain_main)
end

template '/etc/nginx/snippets/ssl-params.conf' do
  source 'ssl-params.conf.erb'
end

template '/etc/nginx/sites-available/web_app' do
  source 'web_app_ssl.erb'
  variables(app_name: app_name,
            port: port,
            domain_main: domain_main,
            domain_secondary: domain_secondary)
  verify 'nginx -t'
end

template '/etc/nginx/nginx.conf' do
  source 'nginx.conf.erb'
end


bash 'set_ufw' do
  code <<-EOH
  ufw delete allow 'Nginx HTTP'
  ufw allow 'Nginx Full'
  EOH
end

service "nginx" do
  action :restart
end
